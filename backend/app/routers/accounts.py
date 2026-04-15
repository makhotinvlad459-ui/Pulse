from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, func
from typing import List

from app.database import get_db
from app.models import User, Company, Account, CompanyMember, UserRole, Transaction
from app.schemas import AccountCreate, AccountResponse
from app.deps import get_current_user

router = APIRouter(prefix="/accounts", tags=["accounts"])

@router.post("/", response_model=AccountResponse)
async def create_account(
    account_data: AccountCreate,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Проверяем, что компания принадлежит пользователю
    result = await db.execute(select(Company).where(Company.id == company_id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found")
    if current_user.role != UserRole.FOUNDER:
        raise HTTPException(status_code=403, detail="Only founder can create accounts")
    if company.founder_id != current_user.id:
        raise HTTPException(status_code=403, detail="You don't have access to this company")
    
    new_account = Account(
        company_id=company_id,
        name=account_data.name,
        type=account_data.type,
        include_in_profit_loss=account_data.include_in_profit_loss,
        balance=0.0
    )
    db.add(new_account)
    await db.commit()
    await db.refresh(new_account)
    return new_account

@router.get("/", response_model=List[AccountResponse])
async def get_accounts(
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Проверяем доступ к компании
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(
            select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id)
        )
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    result = await db.execute(select(Account).where(Account.company_id == company_id))
    accounts = result.scalars().all()
    return accounts

async def _recalc_account_balance(account_id: int, db: AsyncSession):
    """Пересчёт баланса счёта (скопировано из transactions.py)"""
    income = await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0))
        .where(Transaction.account_id == account_id, Transaction.type == 'income', Transaction.is_deleted == False)
    )
    total_income = float(income.scalar())
    expense = await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0))
        .where(Transaction.account_id == account_id, Transaction.type == 'expense', Transaction.is_deleted == False)
    )
    total_expense = float(expense.scalar())
    transfer_out = await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0))
        .where(Transaction.account_id == account_id, Transaction.type == 'transfer', Transaction.is_deleted == False)
    )
    total_transfer_out = float(transfer_out.scalar())
    transfer_in = await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0))
        .where(Transaction.transfer_to_account_id == account_id, Transaction.type == 'transfer', Transaction.is_deleted == False)
    )
    total_transfer_in = float(transfer_in.scalar())
    balance = total_income - total_expense - total_transfer_out + total_transfer_in
    await db.execute(update(Account).where(Account.id == account_id).values(balance=balance))

@router.delete("/{account_id}")
async def delete_account(
    account_id: int,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Проверка, что счёт принадлежит компании учредителя
    result = await db.execute(select(Account).where(Account.id == account_id, Account.company_id == company_id))
    account = result.scalar_one_or_none()
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")
    
    # Проверка, что компания принадлежит учредителю
    result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="Not your company")
    
    # Нельзя удалить системные счета "Наличные" и "Банк"
    if account.type in ('cash', 'bank'):
        raise HTTPException(status_code=400, detail="Cannot delete default cash/bank account")
    
    # Находим или создаём архивный счёт
    archive_account = await db.execute(
        select(Account).where(Account.company_id == company_id, Account.name == "Архив")
    )
    archive_account = archive_account.scalar_one_or_none()
    if not archive_account:
        # Создаём архивный счёт (тип 'other', не участвует в прибыли/убытке)
        archive_account = Account(
            company_id=company_id,
            name="Архив",
            type="other",
            include_in_profit_loss=False,
            balance=0.0
        )
        db.add(archive_account)
        await db.flush()  # чтобы получить id
    
    # Переназначаем все транзакции, где этот счёт был источником
    await db.execute(
        update(Transaction)
        .where(Transaction.account_id == account_id)
        .values(account_id=archive_account.id)
    )
    # Переназначаем все переводы, где этот счёт был получателем
    await db.execute(
        update(Transaction)
        .where(Transaction.transfer_to_account_id == account_id)
        .values(transfer_to_account_id=archive_account.id)
    )
    
    # Удаляем старый счёт
    await db.delete(account)
    await db.commit()
    
    # Пересчитываем баланс архивного счёта (чтобы учесть переназначенные операции)
    await _recalc_account_balance(archive_account.id, db)
    
    return {"detail": "Account deleted, transactions moved to archive"}