from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from typing import List
from pydantic import BaseModel
from datetime import datetime

from app.database import get_db
from app.models import User, Company, ChatMessage, TransactionComment, Transaction, CompanyMember, UserRole
from app.deps import get_current_user

router = APIRouter(prefix="/chat", tags=["chat"])

class ChatMessageCreate(BaseModel):
    message: str

class ChatMessageResponse(BaseModel):
    id: int
    user_id: int
    user_full_name: str
    message: str
    created_at: datetime
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

# ---- Общий чат компании ----
@router.post("/company/{company_id}", response_model=ChatMessageResponse)
async def send_chat_message(
    company_id: int,
    msg: ChatMessageCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Проверка доступа к компании
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    new_msg = ChatMessage(
        company_id=company_id,
        user_id=current_user.id,
        message=msg.message
    )
    db.add(new_msg)
    await db.commit()
    await db.refresh(new_msg)
    return ChatMessageResponse(
        id=new_msg.id,
        user_id=current_user.id,
        user_full_name=current_user.full_name,
        message=new_msg.message,
        created_at=new_msg.created_at
    )

@router.get("/company/{company_id}", response_model=List[ChatMessageResponse])
async def get_chat_messages(
    company_id: int,
    limit: int = 50,
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Проверка доступа
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    result = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.company_id == company_id)
        .order_by(desc(ChatMessage.created_at))
        .offset(offset)
        .limit(limit)
    )
    messages = result.scalars().all()
    # Возвращаем в обратном порядке (от старых к новым) для удобства чата
    messages = list(reversed(messages))
    return [
        ChatMessageResponse(
            id=m.id,
            user_id=m.user_id,
            user_full_name=m.user.full_name,
            message=m.message,
            created_at=m.created_at
        )
        for m in messages
    ]

# ---- Комментарии к операциям ----
@router.post("/transaction/{transaction_id}", response_model=CommentResponse)
async def add_transaction_comment(
    transaction_id: int,
    comment_data: CommentCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Находим транзакцию и проверяем доступ к компании
    result = await db.execute(select(Transaction).where(Transaction.id == transaction_id))
    transaction = result.scalar_one_or_none()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    company_id = transaction.company_id
    
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
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
        user_full_name=current_user.full_name,
        comment=new_comment.comment,
        created_at=new_comment.created_at
    )

@router.get("/transaction/{transaction_id}", response_model=List[CommentResponse])
async def get_transaction_comments(
    transaction_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Проверка доступа к компании через транзакцию
    result = await db.execute(select(Transaction).where(Transaction.id == transaction_id))
    transaction = result.scalar_one_or_none()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    company_id = transaction.company_id
    
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    result = await db.execute(
        select(TransactionComment)
        .where(TransactionComment.transaction_id == transaction_id)
        .order_by(TransactionComment.created_at)
    )
    comments = result.scalars().all()
    return [
        CommentResponse(
            id=c.id,
            user_id=c.user_id,
            user_full_name=c.user.full_name,
            comment=c.comment,
            created_at=c.created_at
        )
        for c in comments
    ]