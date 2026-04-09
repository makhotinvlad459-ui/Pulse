from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List

from app.database import get_db
from app.models import User, Company, Account, CompanyMember, UserRole
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