from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from app.models import CompanyMember
from typing import List
from datetime import datetime
import random
import string

from app.database import get_db
from app.models import User, Company, Account, CompanyMember, UserRole
from app.schemas import CompanyCreate, CompanyResponse
from app.deps import get_current_user
from app.auth import get_password_hash

router = APIRouter(prefix="/companies", tags=["companies"])

def generate_random_password(length=8):
    return ''.join(random.choices(string.ascii_letters + string.digits, k=length))

@router.post("/", response_model=CompanyResponse)
async def create_company(
    company_data: CompanyCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.FOUNDER:
        raise HTTPException(status_code=403, detail="Only founder can create companies")
    
    if current_user.subscription_until and current_user.subscription_until < datetime.utcnow():
        raise HTTPException(status_code=403, detail="Subscription expired")
    
    # Создаём компанию
    new_company = Company(
        founder_id=current_user.id,
        inn=company_data.inn,
        name=company_data.name,
        bank_account=company_data.bank_account,
        manager_full_name=company_data.manager_full_name,
        manager_phone=company_data.manager_phone,
    )
    db.add(new_company)
    await db.flush()
    
    # Создаём обязательные счета
    cash_account = Account(
        company_id=new_company.id,
        name="Наличные",
        type="cash",
        include_in_profit_loss=True,
        balance=0.0
    )
    bank_account = Account(
        company_id=new_company.id,
        name="Банк",
        type="bank",
        include_in_profit_loss=True,
        balance=0.0
    )
    db.add(cash_account)
    db.add(bank_account)
    
    # Добавляем сотрудников
    for emp in company_data.employees:
        phone = emp.get("phone")
        full_name = emp.get("full_name")
        # Проверяем, существует ли пользователь с таким телефоном
        result = await db.execute(select(User).where(User.phone == phone))
        existing = result.scalar_one_or_none()
        if existing:
            raise HTTPException(status_code=400, detail=f"User with phone {phone} already exists")
        
        password = generate_random_password()
        password_hash = get_password_hash(password)
        new_user = User(
            email=f"{phone}@pulse.local",
            phone=phone,
            full_name=full_name,
            password_hash=password_hash,
            role=UserRole.EMPLOYEE,
            subscription_until=None,
            soft_delete_retention_days=15
        )
        db.add(new_user)
        await db.flush()
        
        member = CompanyMember(
            company_id=new_company.id,
            user_id=new_user.id,
            role_in_company="employee",
            invited_by=current_user.id
        )
        db.add(member)
        # Здесь вы можете сохранить пароль в переменную, чтобы потом вернуть учредителю
        # Пока просто печатаем в консоль (в реальности нужно отправить учредителю)
        print(f"Создан сотрудник: {full_name}, телефон: {phone}, пароль: {password}")
    
    await db.commit()
    await db.refresh(new_company)
    
    total = (cash_account.balance or 0) + (bank_account.balance or 0)
    return CompanyResponse(
        id=new_company.id,
        inn=new_company.inn,
        name=new_company.name,
        bank_account=new_company.bank_account,
        manager_full_name=new_company.manager_full_name,
        manager_phone=new_company.manager_phone,
        total_balance=total
    )

@router.get("/", response_model=List[CompanyResponse])
async def get_companies(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(
            select(Company).where(Company.founder_id == current_user.id)
            .options(selectinload(Company.accounts))
        )
    else:
        result = await db.execute(
            select(Company).join(CompanyMember).where(CompanyMember.user_id == current_user.id)
            .options(selectinload(Company.accounts))
        )
    companies = result.scalars().all()
    
    response = []
    for comp in companies:
        total = sum(acc.balance for acc in comp.accounts)
        response.append(CompanyResponse(
            id=comp.id,
            inn=comp.inn,
            name=comp.name,
            bank_account=comp.bank_account,
            manager_full_name=comp.manager_full_name,
            manager_phone=comp.manager_phone,
            total_balance=total
        ))
    return response

@router.get("/{company_id}/members")
async def get_company_members(
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Проверяем, что пользователь имеет доступ к компании (учредитель или сотрудник)
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    # Получаем список участников с информацией о пользователях
    result = await db.execute(
        select(CompanyMember)
        .where(CompanyMember.company_id == company_id)
        .options(selectinload(CompanyMember.user))
    )
    members = result.scalars().all()
    return [
        {
            "id": m.id,
            "user_id": m.user_id,
            "full_name": m.user.full_name,
            "phone": m.user.phone,
            "email": m.user.email,
            "role_in_company": m.role_in_company,
            "joined_at": m.joined_at.isoformat()
        }
        for m in members
    ]

@router.delete("/{company_id}/members/{user_id}")
async def remove_member(
    company_id: int,
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Только учредитель может удалять сотрудников
    if current_user.role != UserRole.FOUNDER:
        raise HTTPException(status_code=403, detail="Only founder can remove members")
    
    # Проверяем, что компания принадлежит учредителю
    result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found")
    
    # Находим связь
    result = await db.execute(select(CompanyMember).where(CompanyMember.company_id == company_id, CompanyMember.user_id == user_id))
    member = result.scalar_one_or_none()
    if not member:
        raise HTTPException(status_code=404, detail="Member not found in this company")
    
    # Нельзя удалить самого учредителя (учредитель не состоит в company_members)
    await db.delete(member)
    await db.commit()
    return {"detail": "Member removed from company"}

@router.post("/{company_id}/members")
async def add_member(
    company_id: int,
    phone: str,
    full_name: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Только учредитель может добавлять сотрудников
    if current_user.role != UserRole.FOUNDER:
        raise HTTPException(status_code=403, detail="Only founder can add members")
    
    # Проверяем компанию
    result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found")
    
    # Проверяем, существует ли пользователь с таким телефоном
    result = await db.execute(select(User).where(User.phone == phone))
    user = result.scalar_one_or_none()
    if not user:
        # Создаём нового сотрудника
        from app.auth import get_password_hash
        import random, string
        def generate_random_password(length=8):
            return ''.join(random.choices(string.ascii_letters + string.digits, k=length))
        password = generate_random_password()
        new_user = User(
            email=f"{phone}@pulse.local",
            phone=phone,
            full_name=full_name,
            password_hash=get_password_hash(password),
            role=UserRole.EMPLOYEE,
            subscription_until=None,
            soft_delete_retention_days=15
        )
        db.add(new_user)
        await db.flush()
        user = new_user
        # Здесь нужно вернуть пароль учредителю (через print или в ответе)
        print(f"Created new user: {full_name}, phone: {phone}, password: {password}")
    else:
        # Проверяем, не состоит ли уже в этой компании
        result = await db.execute(select(CompanyMember).where(CompanyMember.company_id == company_id, CompanyMember.user_id == user.id))
        if result.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="User already a member of this company")
    
    # Добавляем связь
    member = CompanyMember(
        company_id=company_id,
        user_id=user.id,
        role_in_company="employee",
        invited_by=current_user.id
    )
    db.add(member)
    await db.commit()
    return {"detail": "Member added", "user_id": user.id, "full_name": user.full_name, "phone": user.phone}