from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, delete
from sqlalchemy.orm import selectinload
from app.models import CompanyMember
from typing import List
from datetime import datetime
import random
import string

from app.database import get_db
from app.models import User, Company, Account, CompanyMember, UserRole, Category, Permission, CompanyMemberPermission
from app.schemas import CompanyCreate, CompanyResponse,  UpdateMemberRole, SetManagerRequest
from app.deps import get_current_user
from app.auth import get_password_hash

router = APIRouter(prefix="/companies", tags=["companies"])

def generate_random_password(length=8):
    return ''.join(random.choices(string.ascii_letters + string.digits, k=length))

# --- Вспомогательная функция проверки прав на управление сотрудниками ---
async def _can_manage_employees(company_id: int, current_user: User, db: AsyncSession) -> bool:
    # Учредитель может всё
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
        if result.scalar_one_or_none():
            return True
    # Для остальных проверяем наличие права manage_employees
    member = await db.execute(
        select(CompanyMember).where(CompanyMember.company_id == company_id, CompanyMember.user_id == current_user.id)
    )
    member = member.scalar_one_or_none()
    if not member:
        return False
    perm = await db.execute(
        select(CompanyMemberPermission).join(Permission).where(
            CompanyMemberPermission.member_id == member.id,
            Permission.name == 'manage_employees'
        )
    )
    return perm.scalar_one_or_none() is not None

# --- Выдача прав члену компании (без дублирования) ---
async def _grant_permissions_to_member(member_id: int, permission_names: List[str], granter_id: int, db: AsyncSession):
    for perm_name in permission_names:
        perm = await db.execute(select(Permission).where(Permission.name == perm_name))
        perm = perm.scalar_one_or_none()
        if perm:
            existing = await db.execute(
                select(CompanyMemberPermission)
                .where(
                    CompanyMemberPermission.member_id == member_id,
                    CompanyMemberPermission.permission_id == perm.id
                )
                .limit(1)
            )
            if existing.scalar_one_or_none() is None:
                db.add(CompanyMemberPermission(
                    member_id=member_id,
                    permission_id=perm.id,
                    granted_by=granter_id
                ))

# --- Создание компании ---
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
    
    # Предустановленные категории (расширенные)
    preset_categories = [
        {"name": "Реализация", "type": "income", "icon": "💰"},
        {"name": "Продажи", "type": "income", "icon": "📈"},
        {"name": "Транспортные", "type": "expense", "icon": "🚗"},
        {"name": "Касса", "type": "expense", "icon": "💵"},
        {"name": "Офис", "type": "expense", "icon": "🏢"},
        {"name": "Зарплата", "type": "expense", "icon": "👥"},
        {"name": "Налоги", "type": "expense", "icon": "⚖️"},
        {"name": "Магазин", "type": "expense", "icon": "🏬"},
        {"name": "Подрядчики", "type": "expense", "icon": "🤝"},
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
    
    # Добавляем учредителя в company_members (если ещё не добавлен)
    founder_member_exists = await db.execute(
        select(CompanyMember).where(
            CompanyMember.company_id == new_company.id,
            CompanyMember.user_id == current_user.id
        )
    )
    if not founder_member_exists.scalar_one_or_none():
        founder_member = CompanyMember(
            company_id=new_company.id,
            user_id=current_user.id,
            role_in_company='employee',
            invited_by=current_user.id
        )
        db.add(founder_member)
        await db.flush()
        # Выдаём учредителю все права (позже, после получения member_id)
        all_perms = await db.execute(select(Permission))
        for perm in all_perms.scalars().all():
            existing = await db.execute(
                select(CompanyMemberPermission).where(
                    CompanyMemberPermission.member_id == founder_member.id,
                    CompanyMemberPermission.permission_id == perm.id
                ).limit(1)
            )
            if not existing.scalar_one_or_none():
                db.add(CompanyMemberPermission(
                    member_id=founder_member.id,
                    permission_id=perm.id,
                    granted_by=current_user.id
                ))
    
    employees_credentials = []
    
    # --- Создаём пользователя для управляющего ---
    if company_data.manager_phone and company_data.manager_full_name:
        result = await db.execute(select(User).where(User.phone == company_data.manager_phone))
        existing_manager = result.scalar_one_or_none()
        if existing_manager:
            member = CompanyMember(
                company_id=new_company.id,
                user_id=existing_manager.id,
                role_in_company="employee",
                invited_by=current_user.id
            )
            db.add(member)
            await db.flush()
            # Выдаём управляющему расширенные права (кроме manage_permissions и delete_company)
            await _grant_permissions_to_member(member.id, [
                "view_operations", "create_transaction", "edit_transaction",
                "view_showcase", "edit_showcase", "sell_from_showcase",
                "view_chat", "send_messages", "view_tasks", "create_task", "edit_task",
                "manage_employees", "view_accounts", "create_account", "manage_categories",
                "view_reports", "edit_company", "view_archive", "view_documents", "create_documents",
                "edit_documents", "view_requests", "create_requests", "edit_requests",
                "view_products", "create_product", "edit_product",
                "view_materials", "create_material", "edit_material"
            ], current_user.id, db)
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
                role_in_company="employee",
                invited_by=current_user.id
            )
            db.add(member)
            await db.flush()
            await _grant_permissions_to_member(member.id, [
                "view_operations", "create_transaction", "edit_transaction",
                "view_showcase", "edit_showcase", "sell_from_showcase",
                "view_chat", "send_messages", "view_tasks", "create_task", "edit_task",
                "manage_employees", "view_accounts", "create_account", "manage_categories",
                "view_reports", "edit_company", "view_archive", "view_documents", "create_documents",
                "edit_documents", "view_requests", "create_requests", "edit_requests",
                "view_products", "create_product", "edit_product",
                "view_materials", "create_material", "edit_material"
            ], current_user.id, db)
            employees_credentials.append({
                "full_name": company_data.manager_full_name,
                "phone": company_data.manager_phone,
                "password": manager_password,
                "role": "manager"
            })
    
    # --- Добавляем сотрудников (employee) ---
    for emp in company_data.employees:
        phone = emp.get("phone")
        full_name = emp.get("full_name")
        if not phone or not full_name:
            continue
        result = await db.execute(select(User).where(User.phone == phone))
        existing_user = result.scalar_one_or_none()
        if existing_user:
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
                await db.flush()
                await _grant_permissions_to_member(member.id, [
                    "view_operations", "view_showcase", "sell_from_showcase",
                    "view_chat", "send_messages", "view_tasks", "create_task", "edit_task",
                    "view_accounts", "view_reports", "view_documents", "view_requests", "view_products"
                ], current_user.id, db)
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
            await db.flush()
            await _grant_permissions_to_member(member.id, [
                "view_operations", "view_showcase", "sell_from_showcase",
                "view_chat", "send_messages", "view_tasks", "create_task", "edit_task",
                "view_accounts", "view_reports", "view_documents", "view_requests", "view_products"
            ], current_user.id, db)
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

# --- Получение списка компаний пользователя ---
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
        current_user_role = None
        if current_user.role == UserRole.FOUNDER and comp.founder_id == current_user.id:
            current_user_role = 'founder'
        else:
            result = await db.execute(
                select(CompanyMember).where(
                    CompanyMember.company_id == comp.id,
                    CompanyMember.user_id == current_user.id
                )
            )
            member = result.scalar_one_or_none()
            if member:
                current_user_role = member.role_in_company
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

# --- Получение членов компании ---
@router.get("/{company_id}/members")
async def get_company_members(
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Проверка доступа к компании (учредитель или член компании)
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
        company = result.scalar_one_or_none()
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
        company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    # Загружаем членов компании
    result = await db.execute(
        select(CompanyMember)
        .where(CompanyMember.company_id == company_id)
        .options(selectinload(CompanyMember.user))
    )
    members = result.scalars().all()
    
    # Добавляем информацию о том, является ли пользователь учредителем
    return [
        {
            "id": m.id,
            "user_id": m.user_id,
            "full_name": m.user.display_name,
            "phone": m.user.phone,
            "email": m.user.email,
            "role_in_company": m.role_in_company,
            "joined_at": m.joined_at.isoformat(),
            "is_founder": m.user_id == company.founder_id
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
    
    result = await db.execute(select(Company).where(Company.id == company_id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found")
    
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
    await db.flush()
    
    # Выдаём минимальные права новому сотруднику
    await _grant_permissions_to_member(member.id, [
        "view_operations", "view_showcase", "sell_from_showcase",
        "view_chat", "send_messages", "view_tasks", "create_task", "edit_task",
        "view_accounts", "view_reports", "view_documents", "view_requests", "view_products"
    ], current_user.id, db)
    
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

# --- Назначить управляющего компании (без автоматической выдачи прав, только роль) ---
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
    
    # Понизить предыдущего управляющего до employee (если он был)
    result = await db.execute(select(CompanyMember).where(CompanyMember.company_id == company_id, CompanyMember.role_in_company == 'manager'))
    old_manager = result.scalar_one_or_none()
    if old_manager and old_manager.user_id != req.user_id:
        old_manager.role_in_company = 'employee'
    
    # Назначаем новую роль (управляющий получает роль manager)
    member.role_in_company = 'manager'
    
    # Права больше не выдаём автоматически – они управляются через интерфейс прав.
    # Если нужно, чтобы новый управляющий имел какие-то права, выдайте их через отдельный эндпоинт.
    
    await db.commit()
    return {"detail": "Manager updated", "manager_full_name": user.full_name, "manager_phone": user.phone}

# --- Обновление роли участника (только founder) ---
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