from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from sqlalchemy.orm import selectinload
from app.models import CompanyMember
from typing import List
from datetime import datetime
import random
import string

from app.database import get_db
from app.models import User, Company, Account, CompanyMember, UserRole, Category
from app.schemas import CompanyCreate, CompanyResponse,  UpdateMemberRole, SetManagerRequest
from app.deps import get_current_user
from app.auth import get_password_hash

router = APIRouter(prefix="/companies", tags=["companies"])

def generate_random_password(length=8):
    return ''.join(random.choices(string.ascii_letters + string.digits, k=length))

# --- Вспомогательная функция проверки прав на управление сотрудниками ---
async def _can_manage_employees(company_id: int, current_user: User, db: AsyncSession) -> bool:
    """Возвращает True, если текущий пользователь может управлять сотрудниками компании."""
    if current_user.role == UserRole.FOUNDER:
        # Проверяем, что это его компания
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
        if result.scalar_one_or_none():
            return True
    # Проверяем, является ли пользователь менеджером в этой компании
    result = await db.execute(
        select(CompanyMember).where(
            CompanyMember.company_id == company_id,
            CompanyMember.user_id == current_user.id,
            CompanyMember.role_in_company == 'manager'
        )
    )
    if result.scalar_one_or_none():
        return True
    return False

# --- Создание компании (без изменений) ---
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
    
    # Предустановленные категории
    preset_categories = [
        {"name": "Реализация", "type": "income", "icon": "💰"},
        {"name": "Продажи", "type": "income", "icon": "📈"},
        {"name": "Транспортные", "type": "expense", "icon": "🚗"},
        {"name": "Касса", "type": "expense", "icon": "💵"},
        {"name": "Офис", "type": "expense", "icon": "🏢"},
    ]
    for cat in preset_categories:
        category = Category(
            company_id=new_company.id,
            name=cat["name"],
            type=cat["type"],
            is_system=False,
            created_by=current_user.id,
            icon=cat["icon"]
        )
        db.add(category)
    
    employees_credentials = []
    
    # --- Создаём пользователя для управляющего ---
    if company_data.manager_phone and company_data.manager_full_name:
        result = await db.execute(select(User).where(User.phone == company_data.manager_phone))
        existing_manager = result.scalar_one_or_none()
        if existing_manager:
            # Если пользователь уже существует, просто добавляем как менеджера в компанию
            member = CompanyMember(
                company_id=new_company.id,
                user_id=existing_manager.id,
                role_in_company="manager",
                invited_by=current_user.id
            )
            db.add(member)
        else:
            manager_password = generate_random_password()
            manager_password_hash = get_password_hash(manager_password)
            manager_user = User(
                email=f"{company_data.manager_phone}@pulse.local",
                phone=company_data.manager_phone,
                full_name=company_data.manager_full_name,
                password_hash=manager_password_hash,
                role=UserRole.EMPLOYEE,
                subscription_until=None,
                soft_delete_retention_days=15
            )
            db.add(manager_user)
            await db.flush()
            member = CompanyMember(
                company_id=new_company.id,
                user_id=manager_user.id,
                role_in_company="manager",
                invited_by=current_user.id
            )
            db.add(member)
            employees_credentials.append({
                "full_name": company_data.manager_full_name,
                "phone": company_data.manager_phone,
                "password": manager_password,
                "role": "manager"
            })
    
    # --- Добавляем сотрудников ---
    for emp in company_data.employees:
        phone = emp.get("phone")
        full_name = emp.get("full_name")
        if not phone or not full_name:
            continue
        # Проверяем, существует ли пользователь
        result = await db.execute(select(User).where(User.phone == phone))
        existing_user = result.scalar_one_or_none()
        if existing_user:
            # Проверяем, не состоит ли уже в компании
            existing_member = await db.execute(select(CompanyMember).where(
                CompanyMember.company_id == new_company.id,
                CompanyMember.user_id == existing_user.id
            ))
            if not existing_member.scalar_one_or_none():
                member = CompanyMember(
                    company_id=new_company.id,
                    user_id=existing_user.id,
                    role_in_company="employee",
                    invited_by=current_user.id
                )
                db.add(member)
        else:
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
            employees_credentials.append({
                "full_name": full_name,
                "phone": phone,
                "password": password,
                "role": "employee"
            })
    
    await db.commit()
    await db.refresh(new_company)
    
    total_balance = (cash_account.balance or 0) + (bank_account.balance or 0)
    return CompanyResponse(
        id=new_company.id,
        inn=new_company.inn,
        name=new_company.name,
        bank_account=new_company.bank_account,
        manager_full_name=new_company.manager_full_name,
        manager_phone=new_company.manager_phone,
        total_balance=total_balance,
        employees_credentials=employees_credentials
    )

# --- Получение списка компаний (без изменений) ---
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
        
        # Определяем роль текущего пользователя в этой компании
        current_user_role = None
        if current_user.role == UserRole.FOUNDER and comp.founder_id == current_user.id:
            current_user_role = 'founder'
        else:
            # Ищем членство
            result = await db.execute(
                select(CompanyMember).where(
                    CompanyMember.company_id == comp.id,
                    CompanyMember.user_id == current_user.id
                )
            )
            member = result.scalar_one_or_none()
            if member:
                current_user_role = member.role_in_company  # 'manager', 'employee'
        
        response.append(CompanyResponse(
            id=comp.id,
            inn=comp.inn,
            name=comp.name,
            bank_account=comp.bank_account,
            manager_full_name=comp.manager_full_name,
            manager_phone=comp.manager_phone,
            total_balance=total,
            employees_credentials=[],
            current_user_role=current_user_role
        ))
    return response

# --- Получение членов компании (исправлено: используем display_name) ---
@router.get("/{company_id}/members")
async def get_company_members(
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Проверка доступа к компании (учредитель или член компании)
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
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
            "full_name": m.user.display_name,   # <--- исправлено
            "phone": m.user.phone,
            "email": m.user.email,
            "role_in_company": m.role_in_company,
            "joined_at": m.joined_at.isoformat()
        }
        for m in members
    ]

# --- Удаление члена компании ---
@router.delete("/{company_id}/members/{user_id}")
async def remove_member(
    company_id: int,
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _can_manage_employees(company_id, current_user, db):
        raise HTTPException(status_code=403, detail="Only founder or manager can remove members")
    
    result = await db.execute(select(CompanyMember).where(CompanyMember.company_id == company_id, CompanyMember.user_id == user_id))
    member = result.scalar_one_or_none()
    if not member:
        raise HTTPException(status_code=404, detail="Member not found in this company")
    
    await db.delete(member)
    await db.commit()
    return {"detail": "Member removed from company"}

# --- Добавление члена компании ---
@router.post("/{company_id}/members")
async def add_member(
    company_id: int,
    phone: str,
    full_name: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _can_manage_employees(company_id, current_user, db):
        raise HTTPException(status_code=403, detail="Only founder or manager can add members")
    
    # Проверка существования компании
    result = await db.execute(select(Company).where(Company.id == company_id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found")
    
    # Поиск пользователя по телефону
    result = await db.execute(select(User).where(User.phone == phone))
    user = result.scalar_one_or_none()
    created = False
    password = None
    if not user:
        password = generate_random_password()
        password_hash = get_password_hash(password)
        user = User(
            email=f"{phone}@pulse.local",
            phone=phone,
            full_name=full_name,
            password_hash=password_hash,
            role=UserRole.EMPLOYEE,
            subscription_until=None,
            soft_delete_retention_days=15
        )
        db.add(user)
        await db.flush()
        created = True
    else:
        # Проверяем, не является ли уже членом этой компании
        existing = await db.execute(select(CompanyMember).where(CompanyMember.company_id == company_id, CompanyMember.user_id == user.id))
        if existing.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="User already a member of this company")
    
    member = CompanyMember(
        company_id=company_id,
        user_id=user.id,
        role_in_company="employee",
        invited_by=current_user.id
    )
    db.add(member)
    await db.commit()
    
    response_data = {
        "detail": "Member added",
        "user_id": user.id,
        "full_name": user.full_name,
        "phone": user.phone
    }
    if created:
        response_data["password"] = password
    return response_data

# --- Сброс пароля члена компании ---
@router.post("/{company_id}/members/{user_id}/reset-password")
async def reset_member_password(
    company_id: int,
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _can_manage_employees(company_id, current_user, db):
        raise HTTPException(status_code=403, detail="Only founder or manager can reset passwords")
    
    # Проверяем, что пользователь является членом компании
    result = await db.execute(select(CompanyMember).where(CompanyMember.company_id == company_id, CompanyMember.user_id == user_id))
    member = result.scalar_one_or_none()
    if not member:
        raise HTTPException(status_code=404, detail="User is not a member of this company")
    
    new_password = generate_random_password()
    new_password_hash = get_password_hash(new_password)
    await db.execute(update(User).where(User.id == user_id).values(password_hash=new_password_hash))
    await db.commit()
    
    return {"detail": "Password reset", "new_password": new_password}

# --- Редактирование компании ---
@router.put("/{company_id}", response_model=CompanyResponse)
async def update_company(
    company_id: int,
    company_data: CompanyCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.FOUNDER:
        raise HTTPException(status_code=403, detail="Only founder can update companies")
    
    result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found")
    
    company.inn = company_data.inn
    company.name = company_data.name
    company.bank_account = company_data.bank_account
    company.manager_full_name = company_data.manager_full_name
    company.manager_phone = company_data.manager_phone
    
    await db.commit()
    await db.refresh(company)
    
    acc_result = await db.execute(select(Account).where(Account.company_id == company.id))
    accounts = acc_result.scalars().all()
    total_balance = sum(float(acc.balance) for acc in accounts)
    
    return CompanyResponse(
        id=company.id,
        inn=company.inn,
        name=company.name,
        bank_account=company.bank_account,
        manager_full_name=company.manager_full_name,
        manager_phone=company.manager_phone,
        total_balance=total_balance,
        employees_credentials=[]
    )

# --- Назначить управляющего компании ---
@router.put("/{company_id}/manager")
async def set_company_manager(
    company_id: int,
    req: SetManagerRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.FOUNDER:
        raise HTTPException(status_code=403, detail="Only founder can change company manager")
    
    result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found")
    
    result = await db.execute(select(CompanyMember).where(CompanyMember.company_id == company_id, CompanyMember.user_id == req.user_id))
    member = result.scalar_one_or_none()
    if not member:
        raise HTTPException(status_code=404, detail="User is not a member of this company")
    
    result = await db.execute(select(User).where(User.id == req.user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    company.manager_full_name = user.full_name
    company.manager_phone = user.phone
    await db.flush()
    
    result = await db.execute(select(CompanyMember).where(CompanyMember.company_id == company_id, CompanyMember.role_in_company == 'manager'))
    old_manager = result.scalar_one_or_none()
    if old_manager and old_manager.user_id != req.user_id:
        old_manager.role_in_company = 'employee'
    
    member.role_in_company = 'manager'
    
    await db.commit()
    return {"detail": "Manager updated", "manager_full_name": user.full_name, "manager_phone": user.phone}

# --- Обновление роли участника ---
@router.patch("/{company_id}/members/{user_id}/role")
async def update_member_role(
    company_id: int,
    user_id: int,
    req: UpdateMemberRole,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.FOUNDER:
        raise HTTPException(status_code=403, detail="Only founder can change member roles")
    
    result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Company not found")
    
    result = await db.execute(select(CompanyMember).where(CompanyMember.company_id == company_id, CompanyMember.user_id == user_id))
    member = result.scalar_one_or_none()
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")
    
    if req.role_in_company not in ('manager', 'employee'):
        raise HTTPException(status_code=400, detail="Invalid role")
    
    member.role_in_company = req.role_in_company
    await db.commit()
    
    if req.role_in_company == 'manager':
        result = await db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if user:
            company_result = await db.execute(select(Company).where(Company.id == company_id))
            company = company_result.scalar_one_or_none()
            if company:
                company.manager_full_name = user.full_name
                company.manager_phone = user.phone
                await db.commit()
    
    return {"detail": "Role updated", "new_role": req.role_in_company}

# --- Удаление компании ---
@router.delete("/{company_id}")
async def delete_company(
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.FOUNDER:
        raise HTTPException(status_code=403, detail="Only founder can delete companies")
    result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found")
    await db.delete(company)
    await db.commit()
    return {"detail": "Company deleted"}