from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from datetime import datetime, timedelta
from typing import Optional

from app.database import get_db
from app.models import User, Company, Transaction, Category, CompanyMember, UserRole
from app.deps import get_current_user

router = APIRouter(prefix="/statistics", tags=["statistics"])

@router.get("/income")
async def get_income_statistics(
    company_id: int,
    start_date: Optional[datetime] = Query(None),
    end_date: Optional[datetime] = Query(None),
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
    
    if not start_date:
        start_date = datetime.now().replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    if not end_date:
        next_month = start_date.replace(day=28) + timedelta(days=4)
        end_date = next_month - timedelta(days=next_month.day)
        end_date = end_date.replace(hour=23, minute=59, second=59)
    
    # Общая сумма
    total_result = await db.execute(
        select(func.sum(Transaction.amount))
        .where(
            Transaction.company_id == company_id,
            Transaction.type == 'income',
            Transaction.is_deleted == False,
            Transaction.date >= start_date,
            Transaction.date <= end_date
        )
    )
    total_income = total_result.scalar() or 0.0
    
    # По месяцам – используем единое выражение
    month_expr = func.date_trunc('month', Transaction.date)
    monthly_result = await db.execute(
        select(
            month_expr.label('month'),
            func.sum(Transaction.amount).label('total')
        )
        .where(
            Transaction.company_id == company_id,
            Transaction.type == 'income',
            Transaction.is_deleted == False,
            Transaction.date >= start_date,
            Transaction.date <= end_date
        )
        .group_by(month_expr)
        .order_by('month')
    )
    monthly = [{"month": row.month.isoformat(), "total": float(row.total)} for row in monthly_result]
    
    # По категориям
    category_result = await db.execute(
        select(
            Category.name,
            func.sum(Transaction.amount).label('total')
        )
        .join(Transaction, Transaction.category_id == Category.id)
        .where(
            Transaction.company_id == company_id,
            Transaction.type == 'income',
            Transaction.is_deleted == False,
            Transaction.date >= start_date,
            Transaction.date <= end_date
        )
        .group_by(Category.name)
    )
    categories = [{"category": row.name, "total": float(row.total)} for row in category_result]
    
    return {
        "total": float(total_income),
        "start_date": start_date.isoformat(),
        "end_date": end_date.isoformat(),
        "monthly": monthly,
        "by_category": categories
    }

@router.get("/expense")
async def get_expense_statistics(
    company_id: int,
    start_date: Optional[datetime] = Query(None),
    end_date: Optional[datetime] = Query(None),
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
    
    if not start_date:
        start_date = datetime.now().replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    if not end_date:
        next_month = start_date.replace(day=28) + timedelta(days=4)
        end_date = next_month - timedelta(days=next_month.day)
        end_date = end_date.replace(hour=23, minute=59, second=59)
    
    total_result = await db.execute(
        select(func.sum(Transaction.amount))
        .where(
            Transaction.company_id == company_id,
            Transaction.type == 'expense',
            Transaction.is_deleted == False,
            Transaction.date >= start_date,
            Transaction.date <= end_date
        )
    )
    total_expense = total_result.scalar() or 0.0
    
    month_expr = func.date_trunc('month', Transaction.date)
    monthly_result = await db.execute(
        select(
            month_expr.label('month'),
            func.sum(Transaction.amount).label('total')
        )
        .where(
            Transaction.company_id == company_id,
            Transaction.type == 'expense',
            Transaction.is_deleted == False,
            Transaction.date >= start_date,
            Transaction.date <= end_date
        )
        .group_by(month_expr)
        .order_by('month')
    )
    monthly = [{"month": row.month.isoformat(), "total": float(row.total)} for row in monthly_result]
    
    category_result = await db.execute(
        select(
            Category.name,
            func.sum(Transaction.amount).label('total')
        )
        .join(Transaction, Transaction.category_id == Category.id)
        .where(
            Transaction.company_id == company_id,
            Transaction.type == 'expense',
            Transaction.is_deleted == False,
            Transaction.date >= start_date,
            Transaction.date <= end_date
        )
        .group_by(Category.name)
    )
    categories = [{"category": row.name, "total": float(row.total)} for row in category_result]
    
    return {
        "total": float(total_expense),
        "start_date": start_date.isoformat(),
        "end_date": end_date.isoformat(),
        "monthly": monthly,
        "by_category": categories
    }

@router.get("/profit-loss")
async def get_profit_loss(
    company_id: int,
    start_date: Optional[datetime] = Query(None),
    end_date: Optional[datetime] = Query(None),
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
    
    if not start_date:
        start_date = datetime.now().replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    if not end_date:
        next_month = start_date.replace(day=28) + timedelta(days=4)
        end_date = next_month - timedelta(days=next_month.day)
        end_date = end_date.replace(hour=23, minute=59, second=59)
    
    month_expr = func.date_trunc('month', Transaction.date)
    
    income_monthly = await db.execute(
        select(
            month_expr.label('month'),
            func.sum(Transaction.amount).label('income')
        )
        .where(
            Transaction.company_id == company_id,
            Transaction.type == 'income',
            Transaction.is_deleted == False,
            Transaction.date >= start_date,
            Transaction.date <= end_date
        )
        .group_by(month_expr)
    )
    expense_monthly = await db.execute(
        select(
            month_expr.label('month'),
            func.sum(Transaction.amount).label('expense')
        )
        .where(
            Transaction.company_id == company_id,
            Transaction.type == 'expense',
            Transaction.is_deleted == False,
            Transaction.date >= start_date,
            Transaction.date <= end_date
        )
        .group_by(month_expr)
    )
    
    data = {}
    for row in income_monthly:
        month_str = row.month.isoformat()
        data[month_str] = {"month": month_str, "income": float(row.income), "expense": 0.0}
    for row in expense_monthly:
        month_str = row.month.isoformat()
        if month_str in data:
            data[month_str]["expense"] = float(row.expense)
        else:
            data[month_str] = {"month": month_str, "income": 0.0, "expense": float(row.expense)}
    
    result_list = sorted(data.values(), key=lambda x: x["month"])
    
    return {
        "start_date": start_date.isoformat(),
        "end_date": end_date.isoformat(),
        "data": result_list
    }