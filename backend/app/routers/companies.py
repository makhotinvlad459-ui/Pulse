from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, delete, func
from sqlalchemy.orm import selectinload
from app.models import CompanyMember
from typing import List
from datetime import datetime
import random
import string

from app.database import get_db
from app.models import User, Company,Counterparty, Account, CompanyMember, UserRole, Category, Permission, CompanyMemberPermission
from app.schemas import CompanyCreate, CompanyResponse, UpdateMemberRole, SetManagerRequest, CompanyUpdate
from app.deps import get_current_user
from app.auth import get_password_hash
from app.services.subscription_limits import get_company_limit_info

router = APIRouter(prefix="/companies", tags=["companies"], redirect_slashes=False)

def generate_random_password(length=8):
    return ''.join(random.choices(string.ascii_letters + string.digits, k=length))

async def _can_manage_employees(company_id: int, current_user: User, db: AsyncSession) -> bool:
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
        if result.scalar_one_or_none():
            return True
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

@router.post("/", response_model=CompanyResponse)
async def create_company(
    company_data: CompanyCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.FOUNDER:
        raise HTTPException(status_code=403, detail="Only founder can create companies")
    
    # ========== ИСПРАВЛЕННАЯ ПРОВЕРКА ЛИМИТА КОМПАНИЙ ==========
    from app.services.subscription_limits import get_company_limit_info
    limits = await get_company_limit_info(db, current_user)
    
    # Лимит компаний работает всегда: и на бесплатном тарифе (2 шт), 
    # и на платном (2 + extra_companies)
    if limits["remaining_companies"] <= 0:
        raise HTTPException(
            status_code=402,
            detail=f"Достигнут лимит компаний ({limits['companies_used']}/{limits['companies_limit']}). "
        )
    # ====================================================
    
    # Создаём компанию
    inn = company_data.inn or ""
    bank_account = company_data.bank_account or ""

    new_company = Company(
        founder_id=current_user.id,
        inn=inn,
        name=company_data.name,
        bank_account=bank_account,
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
    bank_account_obj = Account(
        company_id=new_company.id,
        name="Банк",
        type="bank",
        include_in_profit_loss=True,
        balance=0.0
    )
    db.add(cash_account)
    db.add(bank_account_obj)
    
    # Предустановленные категории
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
    
    # Добавляем учредителя в company_members
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
            role_in_company='employee',  # Учредитель - особая роль
            invited_by=current_user.id
        )
        db.add(founder_member)
        await db.flush()
        # ВЫДАЁМ УЧРЕДИТЕЛЮ ВСЕ ПРАВА (БЕЗ ПРОВЕРКИ, ТАК КАК ОН НОВЫЙ)
        all_perms = await db.execute(select(Permission))
        for perm in all_perms.scalars().all():
            db.add(CompanyMemberPermission(
                member_id=founder_member.id,
                permission_id=perm.id,
                granted_by=current_user.id
            ))
    
    employees_credentials = []
    
    # --- СОЗДАЁМ ПОЛЬЗОВАТЕЛЯ ДЛЯ УПРАВЛЯЮЩЕГО (role_in_company = "manager") ---
    if company_data.manager_phone and company_data.manager_full_name:
        result = await db.execute(select(User).where(User.phone == company_data.manager_phone))
        existing_manager = result.scalar_one_or_none()
        if existing_manager:
            member = CompanyMember(
                company_id=new_company.id,
                user_id=existing_manager.id,
                role_in_company="manager",  
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
            # Не добавляем в employees_credentials, так как существующий пользователь
        else:
            manager_password = generate_random_password()
            manager_password_hash = get_password_hash(manager_password)
            manager_user = User(
                email=f"{company_data.manager_phone}@pulse.local",
                phone=company_data.manager_phone,
                full_name=company_data.manager_full_name,
                password_hash=manager_password_hash,
                role=UserRole.EMPLOYEE,  # В системе роль EMPLOYEE (не FOUNDER)
                subscription_until=None,
                soft_delete_retention_days=15
            )
            db.add(manager_user)
            await db.flush()
            member = CompanyMember(
                company_id=new_company.id,
                user_id=manager_user.id,
                role_in_company="manager",  # ✅ ИСПРАВЛЕНО: manager, а не employee
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
                "role": "manager"  # ✅ Здесь правильно указано "manager"
            })
    
    # --- ДОБАВЛЯЕМ СОТРУДНИКОВ (role_in_company = "employee") ---
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
    
    total_balance = (cash_account.balance or 0) + (bank_account_obj.balance or 0)
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
    # 1. Получаем компании (с подгрузкой счетов)
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(
            select(Company)
            .where(Company.founder_id == current_user.id)
            .options(selectinload(Company.accounts))
        )
    else:
        result = await db.execute(
            select(Company)
            .join(CompanyMember)
            .where(CompanyMember.user_id == current_user.id)
            .options(selectinload(Company.accounts))
        )
    companies = result.scalars().all()

    if not companies:
        return []

    # 2. ОДНИМ запросом получаем все роли пользователя во всех компаниях
    company_ids = [comp.id for comp in companies]
    members_result = await db.execute(
        select(CompanyMember).where(
            CompanyMember.user_id == current_user.id,
            CompanyMember.company_id.in_(company_ids)
        )
    )
    # Создаём словарь для быстрого поиска роли по company_id
    role_map = {member.company_id: member.role_in_company for member in members_result.scalars()}

    # 3. Формируем ответ, используя подготовленный словарь
    response = []
    for comp in companies:
        total = sum(acc.balance for acc in comp.accounts)
        
        # Определяем роль пользователя в компании
        if current_user.role == UserRole.FOUNDER and comp.founder_id == current_user.id:
            current_user_role = 'founder'
        else:
            current_user_role = role_map.get(comp.id)  # None, если не состоит
        
        response.append(CompanyResponse(
            id=comp.id,
            inn=comp.inn,
            name=comp.name,
            bank_account=comp.bank_account,
            manager_full_name=comp.manager_full_name,
            manager_phone=comp.manager_phone,
            total_balance=total,
            employees_credentials=[],  # если не используется, можно убрать из модели?
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
    
    # ✅ ПОЛУЧАЕМ КОМПАНИЮ
    result = await db.execute(select(Company).where(Company.id == company_id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found")
    
    # Находим удаляемого члена
    result = await db.execute(
        select(CompanyMember)
        .where(
            CompanyMember.company_id == company_id, 
            CompanyMember.user_id == user_id
        )
    )
    member = result.scalar_one_or_none()
    if not member:
        raise HTTPException(status_code=404, detail="Member not found in this company")
    
    # Проверяем, был ли это управляющий
    was_manager = (member.role_in_company == "manager")
    
    # Удаляем члена
    await db.delete(member)
    
    # Если удалили управляющего - назначаем нового
    if was_manager:
        # Ищем другого управляющего
        other_manager = await db.execute(
            select(CompanyMember.user_id)
            .where(
                CompanyMember.company_id == company_id,
                CompanyMember.user_id != user_id,
                CompanyMember.role_in_company == "manager"
            )
            .limit(1)
        )
        other_manager_user_id = other_manager.scalar_one_or_none()
        
        if other_manager_user_id:
            user_data = await db.execute(
                select(User.full_name, User.phone)
                .where(User.id == other_manager_user_id)
            )
            user = user_data.first()
            if user:
                await db.execute(
                    update(Company)
                    .where(Company.id == company_id)
                    .values(
                        manager_full_name=user[0] or "",
                        manager_phone=user[1] or ""
                    )
                )
        else:
            # Назначаем учредителя
            founder = await db.get(User, company.founder_id)
            if founder:
                await db.execute(
                    update(Company)
                    .where(Company.id == company_id)
                    .values(
                        manager_full_name=founder.full_name or "",
                        manager_phone=founder.phone or ""
                    )
                )
            else:
                # Если ничего нет - ставим заглушку
                await db.execute(
                    update(Company)
                    .where(Company.id == company_id)
                    .values(
                        manager_full_name="",
                        manager_phone=""
                    )
                )
    
    # Деактивируем пользователя, если нет других компаний
    other_memberships = await db.execute(
        select(CompanyMember).where(CompanyMember.user_id == user_id)
    )
    if not other_memberships.scalar_one_or_none():
        await db.execute(update(User).where(User.id == user_id).values(is_active=False))
    
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
    company_data: CompanyUpdate,  # Используем новую схему апдейта!
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.FOUNDER:
        raise HTTPException(status_code=403, detail="Only founder can update companies")
    
    result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found")
    
    # Обновляем основные поля
    company.name = company_data.name
    if company_data.inn is not None:
        company.inn = company_data.inn
    if company_data.bank_account is not None:
        company.bank_account = company_data.bank_account
        
    # Если во Flutter-диалоге мы их вообще не передали (пришел None), 
    # то оставляем старые значения, которые уже лежали в базе!
    if company_data.manager_full_name is not None:
        company.manager_full_name = company_data.manager_full_name
    if company_data.manager_phone is not None:
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
    
    # ✅ Понижаем предыдущего управляющего
    result = await db.execute(
        select(CompanyMember)
        .where(
            CompanyMember.company_id == company_id,
            CompanyMember.role_in_company == 'manager'
        )
    )
    old_manager = result.scalar_one_or_none()
    if old_manager and old_manager.user_id != req.user_id:
        old_manager.role_in_company = 'employee'
    
    # ✅ Назначаем нового управляющего
    member.role_in_company = 'manager'
    
    # ✅ ОБНОВЛЯЕМ ПОЛЯ В ТАБЛИЦЕ COMPANY
    await db.execute(
        update(Company)
        .where(Company.id == company_id)
        .values(
            manager_full_name=user.full_name,
            manager_phone=user.phone
        )
    )
    
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
    
    old_role = member.role_in_company
    member.role_in_company = req.role_in_company
    
    user = await db.get(User, user_id)
    
    # ✅ Если назначаем управляющим
    if req.role_in_company == 'manager':
        await db.execute(
            update(Company)
            .where(Company.id == company_id)
            .values(
                manager_full_name=user.full_name if user else None,
                manager_phone=user.phone if user else None
            )
        )
    # ✅ Если снимаем роль управляющего
    elif old_role == 'manager' and req.role_in_company == 'employee':
        # Ищем другого управляющего
        other_manager = await db.execute(
            select(CompanyMember)
            .where(
                CompanyMember.company_id == company_id,
                CompanyMember.user_id != user_id,
                CompanyMember.role_in_company == 'manager'
            )
            .options(selectinload(CompanyMember.user))
            .limit(1)
        )
        other_manager = other_manager.scalar_one_or_none()
        
        if other_manager and other_manager.user:
            await db.execute(
                update(Company)
                .where(Company.id == company_id)
                .values(
                    manager_full_name=other_manager.user.full_name,
                    manager_phone=other_manager.user.phone
                )
            )
        else:
            # Нет другого управляющего - назначаем учредителя
            founder = await db.get(User, current_user.id)
            await db.execute(
                update(Company)
                .where(Company.id == company_id)
                .values(
                    manager_full_name=founder.full_name if founder else "",
                    manager_phone=founder.phone if founder else ""
                )
            )
    
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

@router.put("/{company_id}/members/{user_id}")
async def update_member(
    company_id: int,
    user_id: int,
    data: dict,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _can_manage_employees(company_id, current_user, db):
        raise HTTPException(403, "No permission")
    
    # Проверяем, что пользователь является членом компании
    member = await db.execute(
        select(CompanyMember).where(
            CompanyMember.company_id == company_id,
            CompanyMember.user_id == user_id
        )
    )
    member = member.scalar_one_or_none()
    if not member:
        raise HTTPException(404, "Member not found")
    
    # Обновляем роль, если передана
    if "role_in_company" in data:
        if data["role_in_company"] not in ('manager', 'employee'):
            raise HTTPException(400, "Invalid role")
        member.role_in_company = data["role_in_company"]
    
    # Обновляем имя и телефон в модели User
    user = await db.get(User, user_id)
    if user:
        if "full_name" in data:
            user.full_name = data["full_name"]
        if "phone" in data:
            user.phone = data["phone"]
    
    await db.commit()
    return {"detail": "Member updated"}

@router.get("/{company_id}")
async def get_company(
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Проверка доступа
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
        company = result.scalar_one_or_none()
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
        company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    # Загружаем счета для баланса
    accounts_result = await db.execute(select(Account).where(Account.company_id == company_id))
    accounts = accounts_result.scalars().all()
    total_balance = sum(acc.balance for acc in accounts)
    
    return CompanyResponse(
        id=company.id,
        inn=company.inn,
        name=company.name,
        bank_account=company.bank_account,
        manager_full_name=company.manager_full_name,
        manager_phone=company.manager_phone,
        total_balance=total_balance,
        employees_credentials=[],
        current_user_role=None
    )