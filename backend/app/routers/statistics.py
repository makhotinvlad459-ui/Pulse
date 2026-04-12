from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from datetime import datetime, timedelta
from typing import Optional
from fastapi.responses import FileResponse

from app.database import get_db
from app.models import User, Company, Transaction, Category, CompanyMember, UserRole, Account
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
    
    # По месяцам
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
    
    # По категориям (включая операции без категории)
    category_result = await db.execute(
        select(
            func.coalesce(Category.name, 'Без категории').label('category'),
            func.sum(Transaction.amount).label('total')
        )
        .outerjoin(Category, Transaction.category_id == Category.id)
        .where(
            Transaction.company_id == company_id,
            Transaction.type == 'income',
            Transaction.is_deleted == False,
            Transaction.date >= start_date,
            Transaction.date <= end_date
        )
        .group_by('category')
    )
    categories = [{"category": row.category, "total": float(row.total)} for row in category_result]
    
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
    
    # Общая сумма
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
    
    # По месяцам
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
    
    # По категориям (включая операции без категории)
    category_result = await db.execute(
        select(
            func.coalesce(Category.name, 'Без категории').label('category'),
            func.sum(Transaction.amount).label('total')
        )
        .outerjoin(Category, Transaction.category_id == Category.id)
        .where(
            Transaction.company_id == company_id,
            Transaction.type == 'expense',
            Transaction.is_deleted == False,
            Transaction.date >= start_date,
            Transaction.date <= end_date
        )
        .group_by('category')
    )
    categories = [{"category": row.category, "total": float(row.total)} for row in category_result]
    
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

@router.get("/founder-overview")
async def get_founder_overview(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.FOUNDER:
        raise HTTPException(status_code=403, detail="Only founder can access")
    
    result = await db.execute(select(Company).where(Company.founder_id == current_user.id))
    companies = result.scalars().all()
    
    total_cash = 0.0
    total_bank = 0.0
    
    for company in companies:
        acc_result = await db.execute(select(Account).where(Account.company_id == company.id))
        accounts = acc_result.scalars().all()
        for acc in accounts:
            if acc.type == 'cash':
                total_cash += float(acc.balance)
            elif acc.type == 'bank':
                total_bank += float(acc.balance)
    
    total_all = total_cash + total_bank
    return {
        "total_cash": total_cash,
        "total_bank": total_bank,
        "total_all": total_all
    }

@router.get("/{transaction_id}/photo")
async def get_transaction_photo(
    transaction_id: int,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Проверка доступа к компании (как в других эндпоинтах)
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    # Находим транзакцию
    result = await db.execute(select(Transaction).where(Transaction.id == transaction_id, Transaction.company_id == company_id))
    transaction = result.scalar_one_or_none()
    if not transaction or not transaction.attachment_url:
        raise HTTPException(status_code=404, detail="File not found")
    
    file_path = transaction.attachment_url
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="File not found")
    
    return FileResponse(file_path)