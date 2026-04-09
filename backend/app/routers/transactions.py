from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from typing import List, Optional
from datetime import datetime, timedelta
import os
import shutil

from app.database import get_db
from app.models import User, Company, Account, Category, Transaction, TransactionType, CompanyMember, UserRole
from app.schemas import TransactionCreate, TransactionResponse
from app.deps import get_current_user

router = APIRouter(prefix="/transactions", tags=["transactions"])

async def recalc_account_balance(account_id: int, db: AsyncSession):
    result = await db.execute(
        select(Transaction)
        .where(Transaction.account_id == account_id, Transaction.is_deleted == False)
    )
    transactions = result.scalars().all()
    balance = 0.0
    for t in transactions:
        if t.type == TransactionType.INCOME:
            balance += t.amount
        elif t.type == TransactionType.EXPENSE:
            balance -= t.amount
        elif t.type == TransactionType.TRANSFER:
            balance -= t.amount
    await db.execute(update(Account).where(Account.id == account_id).values(balance=balance))

@router.post("/", response_model=TransactionResponse)
async def create_transaction(
    trans_data: TransactionCreate,
    company_id: int,
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
    
    # Проверка счёта
    result = await db.execute(select(Account).where(Account.id == trans_data.account_id, Account.company_id == company_id))
    account = result.scalar_one_or_none()
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")
    
    # Для перевода проверяем целевой счёт
    if trans_data.type == TransactionType.TRANSFER:
        if not trans_data.transfer_to_account_id:
            raise HTTPException(status_code=400, detail="Transfer requires transfer_to_account_id")
        result = await db.execute(select(Account).where(Account.id == trans_data.transfer_to_account_id, Account.company_id == company_id))
        target_account = result.scalar_one_or_none()
        if not target_account:
            raise HTTPException(status_code=404, detail="Target account not found")
        if trans_data.account_id == trans_data.transfer_to_account_id:
            raise HTTPException(status_code=400, detail="Cannot transfer to the same account")
    
    # Для дохода/расхода проверяем категорию
    if trans_data.type in (TransactionType.INCOME, TransactionType.EXPENSE):
        if not trans_data.category_id:
            result = await db.execute(select(Category).where(Category.company_id == company_id, Category.is_system == True))
            default_cat = result.scalar_one_or_none()
            if not default_cat:
                default_cat = Category(
                    company_id=company_id,
                    name="Без категории",
                    type=trans_data.type,
                    is_system=True,
                    created_by=current_user.id
                )
                db.add(default_cat)
                await db.flush()
            trans_data.category_id = default_cat.id
        else:
            result = await db.execute(select(Category).where(Category.id == trans_data.category_id, Category.company_id == company_id))
            if not result.scalar_one_or_none():
                raise HTTPException(status_code=404, detail="Category not found")
    
    # Приводим дату к naive (без часового пояса)
    if trans_data.date.tzinfo is not None:
        trans_data.date = trans_data.date.replace(tzinfo=None)
    
    new_trans = Transaction(
        company_id=company_id,
        account_id=trans_data.account_id,
        type=trans_data.type,
        amount=trans_data.amount,
        date=trans_data.date,
        category_id=trans_data.category_id,
        description=trans_data.description,
        created_by=current_user.id,
        transfer_to_account_id=trans_data.transfer_to_account_id if trans_data.type == TransactionType.TRANSFER else None
    )
    db.add(new_trans)
    await db.flush()
    
    await recalc_account_balance(trans_data.account_id, db)
    if trans_data.type == TransactionType.TRANSFER:
        await recalc_account_balance(trans_data.transfer_to_account_id, db)
    
    await db.commit()
    await db.refresh(new_trans)
    return new_trans

@router.get("/", response_model=List[TransactionResponse])
async def get_transactions(
    company_id: int,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    type: Optional[TransactionType] = None,
    category_id: Optional[int] = None,
    account_id: Optional[int] = None,
    include_deleted: bool = False,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    query = select(Transaction).where(Transaction.company_id == company_id)
    if not include_deleted:
        query = query.where(Transaction.is_deleted == False)
    if start_date:
        if start_date.tzinfo:
            start_date = start_date.replace(tzinfo=None)
        query = query.where(Transaction.date >= start_date)
    if end_date:
        if end_date.tzinfo:
            end_date = end_date.replace(tzinfo=None)
        query = query.where(Transaction.date <= end_date)
    if type:
        query = query.where(Transaction.type == type)
    if category_id:
        query = query.where(Transaction.category_id == category_id)
    if account_id:
        query = query.where(Transaction.account_id == account_id)
    
    query = query.order_by(Transaction.date.desc())
    result = await db.execute(query)
    transactions = result.scalars().all()
    return transactions

@router.get("/{transaction_id}", response_model=TransactionResponse)
async def get_transaction(
    transaction_id: int,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    result = await db.execute(select(Transaction).where(Transaction.id == transaction_id, Transaction.company_id == company_id))
    transaction = result.scalar_one_or_none()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return transaction

@router.patch("/{transaction_id}", response_model=TransactionResponse)
async def update_transaction(
    transaction_id: int,
    company_id: int,
    trans_data: TransactionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    result = await db.execute(select(Transaction).where(Transaction.id == transaction_id, Transaction.company_id == company_id))
    transaction = result.scalar_one_or_none()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    
    old_account_id = transaction.account_id
    old_transfer_to = transaction.transfer_to_account_id
    
    # Приводим дату к naive
    if trans_data.date.tzinfo is not None:
        trans_data.date = trans_data.date.replace(tzinfo=None)
    
    transaction.account_id = trans_data.account_id
    transaction.type = trans_data.type
    transaction.amount = trans_data.amount
    transaction.date = trans_data.date
    transaction.category_id = trans_data.category_id
    transaction.description = trans_data.description
    transaction.updated_by = current_user.id
    if trans_data.type == TransactionType.TRANSFER:
        transaction.transfer_to_account_id = trans_data.transfer_to_account_id
    else:
        transaction.transfer_to_account_id = None
    
    await db.flush()
    
    await recalc_account_balance(old_account_id, db)
    if old_transfer_to:
        await recalc_account_balance(old_transfer_to, db)
    await recalc_account_balance(transaction.account_id, db)
    if transaction.transfer_to_account_id:
        await recalc_account_balance(transaction.transfer_to_account_id, db)
    
    await db.commit()
    await db.refresh(transaction)
    return transaction

@router.delete("/{transaction_id}")
async def delete_transaction(
    transaction_id: int,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    result = await db.execute(select(Transaction).where(Transaction.id == transaction_id, Transaction.company_id == company_id))
    transaction = result.scalar_one_or_none()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    
    if transaction.is_deleted:
        raise HTTPException(status_code=400, detail="Transaction already deleted")
    
    transaction.is_deleted = True
    transaction.deleted_by = current_user.id
    transaction.deleted_at = datetime.utcnow()
    
    await db.flush()
    await recalc_account_balance(transaction.account_id, db)
    if transaction.transfer_to_account_id:
        await recalc_account_balance(transaction.transfer_to_account_id, db)
    
    await db.commit()
    return {"detail": "Transaction soft-deleted"}

@router.post("/{transaction_id}/restore")
async def restore_transaction(
    transaction_id: int,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    result = await db.execute(select(Transaction).where(Transaction.id == transaction_id, Transaction.company_id == company_id))
    transaction = result.scalar_one_or_none()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    
    if not transaction.is_deleted:
        raise HTTPException(status_code=400, detail="Transaction is not deleted")
    
    transaction.is_deleted = False
    transaction.deleted_by = None
    transaction.deleted_at = None
    
    await db.flush()
    await recalc_account_balance(transaction.account_id, db)
    if transaction.transfer_to_account_id:
        await recalc_account_balance(transaction.transfer_to_account_id, db)
    
    await db.commit()
    return {"detail": "Transaction restored"}

@router.post("/{transaction_id}/upload")
async def upload_transaction_photo(
    transaction_id: int,
    company_id: int,
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    result = await db.execute(select(Transaction).where(Transaction.id == transaction_id, Transaction.company_id == company_id))
    transaction = result.scalar_one_or_none()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    
    upload_dir = f"uploads/company_{company_id}"
    os.makedirs(upload_dir, exist_ok=True)
    file_extension = file.filename.split(".")[-1]
    file_path = f"{upload_dir}/{transaction_id}_{datetime.utcnow().timestamp()}.{file_extension}"
    
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    
    transaction.attachment_url = file_path
    await db.commit()
    return {"detail": "Photo uploaded", "url": file_path}