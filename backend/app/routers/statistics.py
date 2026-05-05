from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, cast, Date
from datetime import datetime, timedelta
from typing import Optional
from fastapi.responses import FileResponse
import os

from app.database import get_db
from app.models import User, Company, Permission, CompanyMemberPermission, Counterparty, Transaction, Category, CompanyMember, UserRole, Account, ShowcaseItem, TransactionItem, Product, Order, OrderItem, OrderStatus
from app.deps import get_current_user

router = APIRouter(prefix="/statistics", tags=["statistics"])

async def _check_company_access(company_id: int, current_user: User, db: AsyncSession) -> bool:
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
        if result.scalar_one_or_none():
            return True
    result = await db.execute(select(CompanyMember).where(CompanyMember.company_id == company_id, CompanyMember.user_id == current_user.id))
    return result.scalar_one_or_none() is not None

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
    
    # Общая сумма (только по счетам с include_in_profit_loss = True)
    total_result = await db.execute(
        select(func.sum(Transaction.amount))
        .join(Account, Transaction.account_id == Account.id)
        .where(
            Transaction.company_id == company_id,
            Transaction.type == 'income',
            Transaction.is_deleted == False,
            Transaction.date >= start_date,
            Transaction.date <= end_date,
            Account.include_in_profit_loss == True
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
        .join(Account, Transaction.account_id == Account.id)
        .where(
            Transaction.company_id == company_id,
            Transaction.type == 'income',
            Transaction.is_deleted == False,
            Transaction.date >= start_date,
            Transaction.date <= end_date,
            Account.include_in_profit_loss == True
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
        .join(Account, Transaction.account_id == Account.id)
        .where(
            Transaction.company_id == company_id,
            Transaction.type == 'income',
            Transaction.is_deleted == False,
            Transaction.date >= start_date,
            Transaction.date <= end_date,
            Account.include_in_profit_loss == True
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
    
    # Общая сумма (только по счетам с include_in_profit_loss = True)
    total_result = await db.execute(
        select(func.sum(Transaction.amount))
        .join(Account, Transaction.account_id == Account.id)
        .where(
            Transaction.company_id == company_id,
            Transaction.type == 'expense',
            Transaction.is_deleted == False,
            Transaction.date >= start_date,
            Transaction.date <= end_date,
            Account.include_in_profit_loss == True
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
        .join(Account, Transaction.account_id == Account.id)
        .where(
            Transaction.company_id == company_id,
            Transaction.type == 'expense',
            Transaction.is_deleted == False,
            Transaction.date >= start_date,
            Transaction.date <= end_date,
            Account.include_in_profit_loss == True
        )
        .group_by(month_expr)
        .order_by('month')
    )
    monthly = [{"month": row.month.isoformat(), "total": float(row.total)} for row in monthly_result]
    
    # По категориям
    category_result = await db.execute(
        select(
            func.coalesce(Category.name, 'Без категории').label('category'),
            func.sum(Transaction.amount).label('total')
        )
        .outerjoin(Category, Transaction.category_id == Category.id)
        .join(Account, Transaction.account_id == Account.id)
        .where(
            Transaction.company_id == company_id,
            Transaction.type == 'expense',
            Transaction.is_deleted == False,
            Transaction.date >= start_date,
            Transaction.date <= end_date,
            Account.include_in_profit_loss == True
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
        .join(Account, Transaction.account_id == Account.id)
        .where(
            Transaction.company_id == company_id,
            Transaction.type == 'income',
            Transaction.is_deleted == False,
            Transaction.date >= start_date,
            Transaction.date <= end_date,
            Account.include_in_profit_loss == True
        )
        .group_by(month_expr)
    )
    expense_monthly = await db.execute(
        select(
            month_expr.label('month'),
            func.sum(Transaction.amount).label('expense')
        )
        .join(Account, Transaction.account_id == Account.id)
        .where(
            Transaction.company_id == company_id,
            Transaction.type == 'expense',
            Transaction.is_deleted == False,
            Transaction.date >= start_date,
            Transaction.date <= end_date,
            Account.include_in_profit_loss == True
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

@router.get("/user-overview")
async def get_user_overview(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Получаем все компании, доступные пользователю
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.founder_id == current_user.id))
        companies = result.scalars().all()
        has_any_accounts_permission = True  # основатель всегда имеет доступ
    else:
        result = await db.execute(
            select(Company).join(CompanyMember).where(CompanyMember.user_id == current_user.id)
        )
        companies = result.scalars().all()
        has_any_accounts_permission = False

    total_cash = 0.0
    total_bank = 0.0

    for company in companies:
        if current_user.role == UserRole.FOUNDER:
            has_permission = True
        else:
            member_res = await db.execute(
                select(CompanyMember).where(CompanyMember.company_id == company.id, CompanyMember.user_id == current_user.id)
            )
            member = member_res.scalar_one_or_none()
            if member:
                perm_res = await db.execute(
                    select(CompanyMemberPermission).join(Permission).where(
                        CompanyMemberPermission.member_id == member.id,
                        Permission.name == 'view_accounts'
                    )
                )
                has_permission = perm_res.scalar_one_or_none() is not None
            else:
                has_permission = False

        if has_permission:
            has_any_accounts_permission = True
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
        "total_all": total_all,
        "has_any_accounts_permission": has_any_accounts_permission
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

# ===================== НОВЫЕ ЭНДПОИНТЫ ДЛЯ ОТЧЁТОВ =====================

from sqlalchemy import text

# ... (оставляем импорты и проверки доступа без изменений)

@router.get("/dynamics")
async def get_dynamics(
    company_id: int,
    start_date: datetime,
    end_date: datetime,
    interval: str = "day",
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Проверка доступа (как было)
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="Access denied")
    
    if start_date.tzinfo is not None:
        start_date = start_date.replace(tzinfo=None)
    if end_date.tzinfo is not None:
        end_date = end_date.replace(tzinfo=None)
    
    # Формат группировки
    if interval == 'day':
        format_sql = "to_char(date_trunc('day', date), 'YYYY-MM-DD')"
    elif interval == 'week':
        format_sql = "to_char(date_trunc('week', date), 'IYYY-IW')"
    elif interval == 'month':
        format_sql = "to_char(date_trunc('month', date), 'YYYY-MM')"
    elif interval == 'year':
        format_sql = "to_char(date_trunc('year', date), 'YYYY')"
    else:
        format_sql = "to_char(date_trunc('day', date), 'YYYY-MM-DD')"
    
    # ИСПРАВЛЕНИЕ: добавляем JOIN с accounts и фильтр по include_in_profit_loss
    query = text(f"""
        WITH periods AS (
            SELECT {format_sql} AS period,
                   SUM(CASE WHEN t.type = 'income' THEN t.amount ELSE 0 END) AS income,
                   SUM(CASE WHEN t.type = 'expense' THEN t.amount ELSE 0 END) AS expense
            FROM transactions t
            JOIN accounts a ON t.account_id = a.id
            WHERE t.company_id = :company_id
              AND t.is_deleted = false
              AND t.date >= :start_date
              AND t.date <= :end_date
              AND a.include_in_profit_loss = true
            GROUP BY period
            ORDER BY period
        )
        SELECT period, income, expense, income - expense AS profit
        FROM periods
    """)
    
    result = await db.execute(query, {
        "company_id": company_id,
        "start_date": start_date,
        "end_date": end_date
    })
    
    rows = result.fetchall()
    return [
        {
            "period": row[0],
            "income": float(row[1]),
            "expense": float(row[2]),
            "profit": float(row[3])
        }
        for row in rows
    ]


@router.get("/cash-vs-noncash")
async def get_cash_vs_noncash(
    company_id: int,
    start_date: datetime,
    end_date: datetime,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if start_date.tzinfo is not None:
        start_date = start_date.replace(tzinfo=None)
    if end_date.tzinfo is not None:
        end_date = end_date.replace(tzinfo=None)
    
    # Проверка доступа
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="Access denied")
    
    # ИСПРАВЛЕНИЕ: учитываем только доходные операции по счетам с include_in_profit_loss = true
    # Также ограничиваем типом 'income' (нас интересуют только поступления)
    cash_query = select(func.sum(Transaction.amount)).where(
        Transaction.company_id == company_id,
        Transaction.is_deleted == False,
        Transaction.date >= start_date,
        Transaction.date <= end_date,
        Transaction.account.has(type='cash', include_in_profit_loss=True),
        Transaction.type == 'income'
    )
    bank_query = select(func.sum(Transaction.amount)).where(
        Transaction.company_id == company_id,
        Transaction.is_deleted == False,
        Transaction.date >= start_date,
        Transaction.date <= end_date,
        Transaction.account.has(type='bank', include_in_profit_loss=True),
        Transaction.type == 'income'
    )
    cash_total = (await db.execute(cash_query)).scalar() or 0
    bank_total = (await db.execute(bank_query)).scalar() or 0
    
    return {
        "cash": float(cash_total),
        "noncash": float(bank_total)
    }


@router.get("/product-sales")
async def get_product_sales(
    company_id: int,
    start_date: datetime,
    end_date: datetime,
    sort_by: str = "quantity",
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Проверка доступа
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="Access denied")
    
    if start_date.tzinfo is not None:
        start_date = start_date.replace(tzinfo=None)
    if end_date.tzinfo is not None:
        end_date = end_date.replace(tzinfo=None)
    
    # ИСПРАВЛЕНИЕ: добавляем JOIN с accounts и фильтр по include_in_profit_loss
    query = select(
        Product.id.label("product_id"),
        Product.name.label("product_name"),
        func.sum(TransactionItem.quantity).label("quantity"),
        func.sum(TransactionItem.quantity * TransactionItem.price_per_unit).label("amount")
    ).select_from(
        TransactionItem
    ).join(
        Transaction, TransactionItem.transaction_id == Transaction.id
    ).join(
        Product, TransactionItem.product_id == Product.id
    ).join(
        Account, Transaction.account_id == Account.id
    ).where(
        Transaction.company_id == company_id,
        Transaction.type == 'income',
        Transaction.is_deleted == False,
        Transaction.date >= start_date,
        Transaction.date <= end_date,
        Transaction.showcase_item_id.is_(None),
        Account.include_in_profit_loss == True
    ).group_by(Product.id, Product.name)
    
    if sort_by == 'quantity':
        query = query.order_by(func.sum(TransactionItem.quantity).desc())
    else:
        query = query.order_by(func.sum(TransactionItem.quantity * TransactionItem.price_per_unit).desc())
    
    result = await db.execute(query)
    rows = result.all()
    return [
        {
            "product_id": r.product_id,
            "product_name": r.product_name,
            "quantity": float(r.quantity),
            "amount": float(r.amount) if r.amount else 0
        }
        for r in rows
    ]


@router.get("/showcase-sales")
async def get_showcase_sales(
    company_id: int,
    start_date: datetime,
    end_date: datetime,
    sort_by: str = "quantity",
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if start_date.tzinfo is not None:
        start_date = start_date.replace(tzinfo=None)
    if end_date.tzinfo is not None:
        end_date = end_date.replace(tzinfo=None)
    # Проверка доступа
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="Access denied")
    
    # ИСПРАВЛЕНИЕ: добавляем JOIN с accounts и фильтр по include_in_profit_loss
    query = select(
        ShowcaseItem.id.label("showcase_item_id"),
        ShowcaseItem.name.label("name"),
        func.sum(Transaction.quantity).label("quantity"),
        func.sum(Transaction.amount).label("amount")
    ).select_from(
        Transaction
    ).join(
        ShowcaseItem, Transaction.showcase_item_id == ShowcaseItem.id
    ).join(
        Account, Transaction.account_id == Account.id
    ).where(
        Transaction.company_id == company_id,
        Transaction.type == 'income',
        Transaction.is_deleted == False,
        Transaction.date >= start_date,
        Transaction.date <= end_date,
        Transaction.showcase_item_id.isnot(None),
        Account.include_in_profit_loss == True
    ).group_by(ShowcaseItem.id, ShowcaseItem.name)
    
    if sort_by == 'quantity':
        query = query.order_by(func.sum(Transaction.quantity).desc())
    else:
        query = query.order_by(func.sum(Transaction.amount).desc())
    
    result = await db.execute(query)
    rows = result.all()
    return [
        {
            "showcase_item_id": r.showcase_item_id,
            "name": r.name,
            "quantity": r.quantity if r.quantity is not None else 0,
            "amount": float(r.amount) if r.amount else 0
        }
        for r in rows
    ]


@router.get("/product-income")
async def get_product_income(
    company_id: int,
    start_date: datetime,
    end_date: datetime,
    sort_by: str = "quantity",
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Проверка доступа
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="Access denied")
    
    if start_date.tzinfo is not None:
        start_date = start_date.replace(tzinfo=None)
    if end_date.tzinfo is not None:
        end_date = end_date.replace(tzinfo=None)
    
    # ИСПРАВЛЕНИЕ: учитываем только счета с include_in_profit_loss == True
    query = select(
        Product.id.label("product_id"),
        Product.name.label("product_name"),
        func.sum(TransactionItem.quantity).label("quantity"),
        func.sum(TransactionItem.quantity * TransactionItem.price_per_unit).label("amount")
    ).select_from(
        TransactionItem
    ).join(
        Transaction, TransactionItem.transaction_id == Transaction.id
    ).join(
        Product, TransactionItem.product_id == Product.id
    ).join(
        Account, Transaction.account_id == Account.id
    ).where(
        Transaction.company_id == company_id,
        Transaction.type == 'expense',
        Transaction.is_deleted == False,
        Transaction.date >= start_date,
        Transaction.date <= end_date,
        Account.include_in_profit_loss == True
    ).group_by(Product.id, Product.name)
    
    if sort_by == 'quantity':
        query = query.order_by(func.sum(TransactionItem.quantity).desc())
    else:
        query = query.order_by(func.sum(TransactionItem.quantity * TransactionItem.price_per_unit).desc())
    
    result = await db.execute(query)
    rows = result.all()
    return [
        {
            "product_id": r.product_id,
            "product_name": r.product_name,
            "quantity": float(r.quantity),
            "amount": float(r.amount) if r.amount else 0
        }
        for r in rows
    ]


@router.get("/product-consumption")
async def get_product_consumption(
    company_id: int,
    start_date: datetime,
    end_date: datetime,
    sort_by: str = "quantity",
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Проверка доступа
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="Access denied")
    
    if start_date.tzinfo is not None:
        start_date = start_date.replace(tzinfo=None)
    if end_date.tzinfo is not None:
        end_date = end_date.replace(tzinfo=None)
    
    # ИСПРАВЛЕНИЕ: учитываем только счета с include_in_profit_loss == True
    query = select(
        Product.id.label("product_id"),
        Product.name.label("product_name"),
        func.sum(TransactionItem.quantity).label("quantity"),
        func.sum(TransactionItem.quantity * TransactionItem.price_per_unit).label("amount")
    ).select_from(
        TransactionItem
    ).join(
        Transaction, TransactionItem.transaction_id == Transaction.id
    ).join(
        Product, TransactionItem.product_id == Product.id
    ).join(
        Account, Transaction.account_id == Account.id
    ).where(
        Transaction.company_id == company_id,
        Transaction.type == 'income',
        Transaction.is_deleted == False,
        Transaction.date >= start_date,
        Transaction.date <= end_date,
        Account.include_in_profit_loss == True
    ).group_by(Product.id, Product.name)
    
    if sort_by == 'quantity':
        query = query.order_by(func.sum(TransactionItem.quantity).desc())
    else:
        query = query.order_by(func.sum(TransactionItem.quantity * TransactionItem.price_per_unit).desc())
    
    result = await db.execute(query)
    rows = result.all()
    return [
        {
            "product_id": r.product_id,
            "product_name": r.product_name,
            "quantity": float(r.quantity),
            "amount": float(r.amount) if r.amount else 0
        }
        for r in rows
    ]

@router.get("/order-materials-consumption")
async def get_order_materials_consumption(
    company_id: int,
    start_date: datetime,
    end_date: datetime,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    
    stmt = (
        select(
            Product.name,
            Product.unit,
            func.sum(OrderItem.quantity).label('total_quantity'),
            func.sum(OrderItem.total).label('total_cost')
        )
        .join(OrderItem, OrderItem.product_id == Product.id)
        .join(Order, Order.id == OrderItem.order_id)
        .where(Order.company_id == company_id)
        .where(Order.status == OrderStatus.COMPLETED)
        .where(Order.completed_at >= start_date)
        .where(Order.completed_at <= end_date)
        .group_by(Product.id)
    )
    result = await db.execute(stmt)
    return result.mappings().all()

@router.get("/order-stats")
async def get_order_stats(
    company_id: int,
    start_date: datetime,
    end_date: datetime,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    
    stats = {}
    for status in OrderStatus:
        stmt = select(
            func.count(Order.id).label('count'),
            func.sum(Order.total_amount).label('total_sum')
        ).where(
            Order.company_id == company_id,
            Order.status == status,
            Order.created_at.between(start_date, end_date)
        )
        row = (await db.execute(stmt)).one()
        stats[status.value] = {
            'count': row.count or 0,
            'total_sum': float(row.total_sum or 0) if row.total_sum else 0.0
        }
    return stats

@router.get("/counterparties")
async def get_counterparties(
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    
    # Имена из таблицы Counterparty
    cp_result = await db.execute(select(Counterparty.name).where(Counterparty.company_id == company_id))
    cp_names = [row[0] for row in cp_result.all()]
    
    # Имена из транзакций
    tx_result = await db.execute(
        select(Transaction.counterparty).distinct().where(
            Transaction.company_id == company_id,
            Transaction.counterparty.isnot(None),
            Transaction.counterparty != ''
        )
    )
    tx_names = [row[0] for row in tx_result.all()]
    
    # Объединяем и убираем дубликаты
    all_names = sorted(set(cp_names + tx_names))
    return all_names

@router.get("/counterparty-stats")
async def get_counterparty_stats(
    company_id: int,
    counterparty: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    
    # Ищем все транзакции с этим контрагентом без учёта регистра
    from sqlalchemy import func
    counterparty_lower = counterparty.lower()
    
    income_result = await db.execute(
        select(func.sum(Transaction.amount)).where(
            Transaction.company_id == company_id,
            func.lower(Transaction.counterparty) == counterparty_lower,
            Transaction.type == 'income',
            Transaction.is_deleted == False
        )
    )
    total_income = income_result.scalar_one_or_none() or 0
    
    expense_result = await db.execute(
        select(func.sum(Transaction.amount)).where(
            Transaction.company_id == company_id,
            func.lower(Transaction.counterparty) == counterparty_lower,
            Transaction.type == 'expense',
            Transaction.is_deleted == False
        )
    )
    total_expense = expense_result.scalar_one_or_none() or 0
    
    transactions_result = await db.execute(
        select(Transaction).where(
            Transaction.company_id == company_id,
            func.lower(Transaction.counterparty) == counterparty_lower,
            Transaction.is_deleted == False
        ).order_by(Transaction.date.desc()).limit(50)
    )
    transactions = transactions_result.scalars().all()
    
    return {
        "counterparty": counterparty,  # возвращаем то, что ввели
        "total_income": float(total_income),
        "total_expense": float(total_expense),
        "balance": float(total_income) - float(total_expense),
        "transactions": [
            {
                "id": t.id,
                "type": t.type,
                "amount": float(t.amount),
                "date": t.date.isoformat(),
                "description": t.description
            } for t in transactions
        ]
    }

@router.get("/counterparties-report")
async def get_counterparties_report(
    company_id: int,
    start_date: datetime,
    end_date: datetime,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    
    income_stmt = select(
        Transaction.counterparty,
        func.sum(Transaction.amount).label('total_income')
    ).where(
        Transaction.company_id == company_id,
        Transaction.counterparty.isnot(None),
        Transaction.counterparty != '',
        Transaction.type == 'income',
        Transaction.is_deleted == False,
        Transaction.date >= start_date,
        Transaction.date <= end_date
    ).group_by(Transaction.counterparty)
    expense_stmt = select(
        Transaction.counterparty,
        func.sum(Transaction.amount).label('total_expense')
    ).where(
        Transaction.company_id == company_id,
        Transaction.counterparty.isnot(None),
        Transaction.counterparty != '',
        Transaction.type == 'expense',
        Transaction.is_deleted == False,
        Transaction.date >= start_date,
        Transaction.date <= end_date
    ).group_by(Transaction.counterparty)
    income_rows = (await db.execute(income_stmt)).all()
    expense_rows = (await db.execute(expense_stmt)).all()
    data = {}
    for row in income_rows:
        data[row.counterparty] = {"name": row.counterparty, "total_income": float(row.total_income), "total_expense": 0.0}
    for row in expense_rows:
        if row.counterparty in data:
            data[row.counterparty]["total_expense"] = float(row.total_expense)
        else:
            data[row.counterparty] = {"name": row.counterparty, "total_income": 0.0, "total_expense": float(row.total_expense)}
    result = []
    for item in data.values():
        item["balance"] = item["total_income"] - item["total_expense"]
        result.append(item)
    result.sort(key=lambda x: x["name"])
    return result