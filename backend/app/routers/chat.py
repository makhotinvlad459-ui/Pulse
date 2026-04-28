import os
import shutil
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from sqlalchemy.orm import selectinload
from pydantic import BaseModel

from app.database import get_db
from app.models import User, Company, ChatMessage, TransactionComment, Transaction, CompanyMember, UserRole, UserChatVisit
from app.deps import get_current_user
from app.websocket_manager import manager

router = APIRouter(prefix="/chat", tags=["chat"])

# ========== Pydantic модели ==========
class ChatMessageCreate(BaseModel):
    message: str
    attachment_url: Optional[str] = None

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

# ========== Загрузка файлов ==========
UPLOAD_DIR = "uploads/chat"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@router.post("/upload")
async def upload_chat_file(
    company_id: int = Form(...),
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Проверка доступа к компании
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(status_code=403, detail="Access denied to this company")

    # Генерируем безопасное имя файла
    timestamp = int(datetime.utcnow().timestamp())
    safe_filename = f"{current_user.id}_{timestamp}_{file.filename}"
    file_path = os.path.join(UPLOAD_DIR, safe_filename)

    # Сохраняем файл
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    # Возвращаем URL для доступа к файлу
    file_url = f"/uploads/chat/{safe_filename}"
    return {"url": file_url}

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
        attachment_url=msg.attachment_url,   # СОХРАНЯЕМ ВЛОЖЕНИЕ
        edited=False
    )
    db.add(new_msg)
    await db.commit()
    await db.refresh(new_msg)
    
    # Отправляем через WebSocket
    await manager.broadcast_chat(company_id, {
        "type": "new_message",
        "message": {
            "id": new_msg.id,
            "user_id": current_user.id,
            "user_full_name": current_user.display_name,
            "message": new_msg.message,
            "attachment_url": new_msg.attachment_url,  # ВЛОЖЕНИЕ В ВЕБСОКЕТ
            "created_at": new_msg.created_at.isoformat(),
            "edited": False,
            "updated_at": None,
        }
    })
    
    # Уведомляем о непрочитанных
    await manager.notify_company_members(company_id, {
        "type": "update_counters",
        "company_id": company_id
    }, db)
    
    return ChatMessageResponse(
        id=new_msg.id,
        user_id=current_user.id,
        user_full_name=current_user.display_name,
        message=new_msg.message,
        attachment_url=new_msg.attachment_url,  # ВЛОЖЕНИЕ В ОТВЕТЕ
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
            attachment_url=m.attachment_url,   # ВЛОЖЕНИЕ В СПИСКЕ
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

# ========== Комментарии к операциям (без изменений) ==========
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