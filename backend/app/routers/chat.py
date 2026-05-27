import os
from datetime import datetime, timedelta
from typing import List, Optional
import io
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from sqlalchemy.orm import selectinload
from pydantic import BaseModel
from firebase_admin import storage, messaging  # Подключаем Firebase Storage и пуши

from app.database import get_db
from app.models import User, Company, ChatMessage, TransactionComment, Transaction, CompanyMember, UserRole, UserChatVisit
from app.deps import get_current_user
from app.websocket_manager import manager

router = APIRouter(prefix="/chat", tags=["chat"], redirect_slashes=False)

# ========== Pydantic модели ==========
class ChatMessageCreate(BaseModel):
    message: str
    attachment_url: Optional[str] = None

class UpdateFCMTokenRequest(BaseModel):
    fcm_token: str    

class EditMessageRequest(BaseModel):
    message: str

class ChatMessageResponse(BaseModel):
    id: int
    user_id: int
    user_full_name: str
    message: str
    attachment_url: Optional[str] = None
    created_at: datetime
    edited: bool = False
    updated_at: datetime | None = None
    class Config:
        from_attributes = True

class CommentCreate(BaseModel):
    comment: str

class CommentResponse(BaseModel):
    id: int
    user_id: int
    user_full_name: str
    comment: str
    created_at: datetime
    class Config:
        from_attributes = True

# ========== Вспомогательная функция проверки доступа ==========
async def _check_company_access(company_id: int, current_user: User, db: AsyncSession) -> bool:
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    return result.scalar_one_or_none() is not None

# ========== Загрузка файлов СРАЗУ В FIREBASE STORAGE ==========
@router.post("/upload")
async def upload_chat_file(
    company_id: int = Form(...),
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # 1. Проверяем доступ пользователя к компании
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(status_code=403, detail="Access denied to this company")

    try:
        # 2. Формируем уникальное имя файла для облака
        timestamp = int(datetime.utcnow().timestamp())
        blob_name = f"chat_{company_id}/{timestamp}_{file.filename}"

        # 3. Подключаемся к бакету Firebase
        bucket = storage.bucket()
        blob = bucket.blob(blob_name)

        # 4. Читаем файл и заливаем в Firebase Storage
        file_content = await file.read()
        blob.upload_from_string(file_content, content_type=file.content_type)

        # 5. Вместо прямой ссылки Google Storage, которая блокируется по CORS,
        # отдаем относительный URL на наш собственный прокси-эндпоинт бэкенда.
        return {"url": f"/api/chat/file/{blob_name}"}

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to upload file to Firebase: {str(e)}")

# ========== Проксирование файлов для обхода CORS во Flutter Web ==========
@router.get("/file/{folder}/{file_name}")
async def get_chat_file(folder: str, file_name: str):
    """Проксирует файл из Firebase Storage наружу, полностью обходя CORS во Flutter Web"""
    try:
        bucket = storage.bucket()
        # Восстанавливаем полный путь к файлу внутри бакета (например: chat_1/1779899002_logo.png)
        blob_path = f"{folder}/{file_name}"
        blob = bucket.blob(blob_path)

        if not blob.exists():
            raise HTTPException(status_code=404, detail="Файл не найден в хранилище")

        # Скачиваем файл в буфер оперативной памяти сервера
        file_stream = io.BytesIO()
        blob.download_to_file(file_stream)
        file_stream.seek(0)

        # Вытаскиваем оригинальный content_type (image/png, image/jpeg и т.д.)
        content_type = blob.content_type or "application/octet-stream"

        return StreamingResponse(file_stream, media_type=content_type)

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ошибка при чтении файла из Firebase: {str(e)}")

# ========== Чат компании ==========
@router.post("/company/{company_id}", response_model=ChatMessageResponse)
async def send_chat_message(
    company_id: int,
    msg: ChatMessageCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    new_msg = ChatMessage(
        company_id=company_id,
        user_id=current_user.id,
        message=msg.message,
        attachment_url=msg.attachment_url,   # Сохраняем готовую ссылку нашего API
        edited=False
    )
    db.add(new_msg)
    await db.commit()
    await db.refresh(new_msg)
    
    # Готовим пакет данных для реалтайма
    ws_message_data = {
        "id": new_msg.id,
        "user_id": current_user.id,
        "user_full_name": current_user.display_name,
        "message": new_msg.message,
        "attachment_url": new_msg.attachment_url,  # Ссылка летит в WebSocket
        "created_at": new_msg.created_at.isoformat(),
        "edited": False,
        "updated_at": None,
    }

    # Отправляем через WebSocket всем, кто ОНЛАЙН в чате этой компании
    await manager.broadcast_chat(company_id, {
        "type": "new_message",
        "message": ws_message_data
    })
    
    # Обновляем красные точки (счётчики) непрочитанных у всей компании
    await manager.notify_company_members(company_id, {
        "type": "update_counters",
        "company_id": company_id
    }, db)
    
    return ChatMessageResponse(
        id=new_msg.id,
        user_id=current_user.id,
        user_full_name=current_user.display_name,
        message=new_msg.message,
        attachment_url=new_msg.attachment_url,
        created_at=new_msg.created_at,
        edited=new_msg.edited,
        updated_at=new_msg.updated_at
    )

@router.get("/company/{company_id}", response_model=List[ChatMessageResponse])
async def get_chat_messages(
    company_id: int,
    limit: int = 100,
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    result = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.company_id == company_id)
        .order_by(ChatMessage.created_at.desc())
        .offset(offset)
        .limit(limit)
        .options(selectinload(ChatMessage.user))
    )
    messages = result.scalars().all()
    messages = list(reversed(messages))
    return [
        ChatMessageResponse(
            id=m.id,
            user_id=m.user_id,
            user_full_name=m.user.display_name,
            message=m.message,
            attachment_url=m.attachment_url,
            created_at=m.created_at,
            edited=m.edited,
            updated_at=m.updated_at
        )
        for m in messages
    ]

@router.post("/company/{company_id}/mark-read")
async def mark_chat_read(
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    stmt = select(UserChatVisit).where(
        UserChatVisit.user_id == current_user.id,
        UserChatVisit.company_id == company_id
    )
    visit = await db.execute(stmt)
    visit = visit.scalar_one_or_none()
    if not visit:
        visit = UserChatVisit(user_id=current_user.id, company_id=company_id)
        db.add(visit)
    visit.last_visit_at = datetime.utcnow()
    await db.commit()
    return {"detail": "Chat marked as read"}

@router.patch("/message/{message_id}")
async def edit_message(
    message_id: int,
    req: EditMessageRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(ChatMessage).where(ChatMessage.id == message_id))
    msg = result.scalar_one_or_none()
    if not msg:
        raise HTTPException(status_code=404, detail="Message not found")
    if msg.user_id != current_user.id and current_user.role != UserRole.FOUNDER:
        raise HTTPException(status_code=403, detail="Not authorized to edit this message")
    msg.message = req.message
    msg.edited = True
    msg.updated_at = datetime.utcnow()
    await db.commit()
    
    await manager.broadcast_chat(msg.company_id, {
        "type": "edit_message",
        "message_id": msg.id,
        "new_message": msg.message,
        "updated_at": msg.updated_at.isoformat(),
    })
    await manager.notify_company_members(msg.company_id, {
        "type": "update_counters",
        "company_id": msg.company_id
    }, db)
    
    return {"detail": "Message edited"}

@router.delete("/company/{company_id}/clear")
async def clear_chat(
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.FOUNDER:
        raise HTTPException(status_code=403, detail="Only founder can clear chat")
    result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Company not found")
    await db.execute(delete(ChatMessage).where(ChatMessage.company_id == company_id))
    await db.commit()
    
    await manager.broadcast_chat(company_id, {"type": "clear_chat"})
    await manager.notify_company_members(company_id, {
        "type": "update_counters",
        "company_id": company_id
    }, db)
    
    return {"detail": "Chat cleared"}

# ========== Комментарии к операциям ==========
@router.post("/transaction/{transaction_id}", response_model=CommentResponse)
async def add_transaction_comment(
    transaction_id: int,
    comment_data: CommentCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(Transaction).where(Transaction.id == transaction_id))
    transaction = result.scalar_one_or_none()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    company_id = transaction.company_id
    
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    new_comment = TransactionComment(
        transaction_id=transaction_id,
        user_id=current_user.id,
        comment=comment_data.comment
    )
    db.add(new_comment)
    await db.commit()
    await db.refresh(new_comment)
    return CommentResponse(
        id=new_comment.id,
        user_id=current_user.id,
        user_full_name=current_user.display_name,
        comment=new_comment.comment,
        created_at=new_comment.created_at
    )

@router.get("/transaction/{transaction_id}", response_model=List[CommentResponse])
async def get_transaction_comments(
    transaction_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(Transaction).where(Transaction.id == transaction_id))
    transaction = result.scalar_one_or_none()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    company_id = transaction.company_id
    
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    result = await db.execute(
        select(TransactionComment)
        .where(TransactionComment.transaction_id == transaction_id)
        .order_by(TransactionComment.created_at)
        .options(selectinload(TransactionComment.user))
    )
    comments = result.scalars().all()
    return [
        CommentResponse(
            id=c.id,
            user_id=c.user_id,
            user_full_name=c.user.display_name,
            comment=c.comment,
            created_at=c.created_at
        )
        for c in comments
    ]

@router.delete("/message/{message_id}")
async def delete_message(
    message_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(ChatMessage).where(ChatMessage.id == message_id))
    msg = result.scalar_one_or_none()
    if not msg:
        raise HTTPException(status_code=404, detail="Message not found")
    if msg.user_id != current_user.id and current_user.role != UserRole.FOUNDER:
        raise HTTPException(status_code=403, detail="Not authorized")
    await db.delete(msg)
    await db.commit()

    await manager.broadcast_chat(msg.company_id, {
        "type": "delete_message",
        "message_id": message_id,
    })
    await manager.notify_company_members(msg.company_id, {
        "type": "update_counters",
        "company_id": msg.company_id
    }, db)
    return {"detail": "Message deleted"}

@router.post("/fcm-token")
async def update_fcm_token(
    req: UpdateFCMTokenRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    try:
        # Обновляем токен у текущего авторизованного пользователя
        current_user.fcm_token = req.fcm_token
        await db.commit()
        return {"status": "success", "detail": "FCM token updated successfully"}
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to update FCM token: {str(e)}")