from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, or_
from datetime import datetime, timedelta
from typing import Optional, List
from decimal import Decimal

from app.database import get_db
from app.models import User, Company, Transaction, UserRole
from app.deps import get_current_user

router = APIRouter(prefix="/admin", tags=["admin"])

async def require_superadmin(current_user: User = Depends(get_current_user)):
    if current_user.role != UserRole.SUPERADMIN:
        raise HTTPException(status_code=403, detail="Superadmin required")
    return current_user

@router.get("/stats")
async def get_admin_stats(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_superadmin)
):
    now = datetime.utcnow()
    month_ago = now - timedelta(days=30)

    # Учредители
    founders_total = await db.execute(select(func.count()).where(User.role == UserRole.FOUNDER))
    founders_total = founders_total.scalar()
    founders_active = await db.execute(select(func.count()).where(
        User.role == UserRole.FOUNDER,
        User.subscription_until > now
    ))
    founders_active = founders_active.scalar()
    founders_expired = founders_total - founders_active

    # Сотрудники
    employees_total = await db.execute(select(func.count()).where(User.role == UserRole.EMPLOYEE))
    employees_total = employees_total.scalar()
    employees_active = await db.execute(select(func.count()).where(
        User.role == UserRole.EMPLOYEE,
        User.last_login > month_ago
    ))
    employees_active = employees_active.scalar()
    employees_inactive = employees_total - employees_active

    # Компании
    companies_total = await db.execute(select(func.count()).select_from(Company))
    companies_total = companies_total.scalar()
    companies_per_founder = companies_total / founders_total if founders_total else 0

    # Транзакции
    transactions_total = await db.execute(select(func.count()).select_from(Transaction))
    transactions_total = transactions_total.scalar()
    transactions_last_month = await db.execute(
        select(func.count()).where(Transaction.date >= month_ago)
    )
    transactions_last_month = transactions_last_month.scalar()

    # Регистрации по месяцам (последние 6 месяцев)
    month_labels = []
    registrations = []
    for i in range(5, -1, -1):
        month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0) - timedelta(days=30*i)
        month_end = (month_start + timedelta(days=32)).replace(day=1) - timedelta(microseconds=1)
        count = await db.execute(
            select(func.count()).where(
                User.created_at >= month_start,
                User.created_at <= month_end,
                User.role != UserRole.SUPERADMIN
            )
        )
        month_labels.append(month_start.strftime("%Y-%m"))
        registrations.append(count.scalar())

    return {
        "founders": {
            "total": founders_total,
            "active_subscription": founders_active,
            "expired_subscription": founders_expired
        },
        "employees": {
            "total": employees_total,
            "active_last_30_days": employees_active,
            "inactive_last_30_days": employees_inactive
        },
        "companies": {
            "total": companies_total,
            "average_per_founder": round(companies_per_founder, 2)
        },
        "transactions": {
            "total": transactions_total,
            "last_30_days": transactions_last_month
        },
        "registrations_last_6_months": {
            "months": month_labels,
            "counts": registrations
        }
    }

@router.get("/users")
async def list_users(
    role: Optional[UserRole] = Query(None),
    is_active_subscription: Optional[bool] = Query(None),
    limit: int = 100,
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_superadmin)
):
    query = select(User)
    if role:
        query = query.where(User.role == role)
    if is_active_subscription is not None:
        now = datetime.utcnow()
        if is_active_subscription:
            query = query.where(User.subscription_until > now)
        else:
            query = query.where(or_(User.subscription_until <= now, User.subscription_until == None))
    query = query.offset(offset).limit(limit)
    result = await db.execute(query)
    users = result.scalars().all()
    return [
        {
            "id": u.id,
            "email": u.email,
            "phone": u.phone,
            "full_name": u.full_name,
            "role": u.role.value,
            "subscription_until": u.subscription_until.isoformat() if u.subscription_until else None,
            "last_login": u.last_login.isoformat() if u.last_login else None,
            "created_at": u.created_at.isoformat()
        }
        for u in users
    ]

@router.get("/companies")
async def list_all_companies(
    limit: int = 100,
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_superadmin)
):
    result = await db.execute(
        select(Company).offset(offset).limit(limit)
    )
    companies = result.scalars().all()
    # Дополнительно подгрузим учредителя
    return [
        {
            "id": c.id,
            "name": c.name,
            "inn": c.inn,
            "founder_id": c.founder_id,
            "created_at": c.created_at.isoformat()
        }
        for c in companies
    ]