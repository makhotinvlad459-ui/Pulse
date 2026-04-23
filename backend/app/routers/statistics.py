from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, cast, Date
from datetime import datetime, timedelta
from typing import Optional
from fastapi.responses import FileResponse
import os

from app.database import get_db
from app.models import User, Company, Transaction, Category, CompanyMember, UserRole, Account, ShowcaseItem, TransactionItem, Product
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
    else:
        # Сотрудник: компании через CompanyMember
        result = await db.execute(
            select(Company).join(CompanyMember).where(CompanyMember.user_id == current_user.id)
        )
    companies = result.scalars().all()
    
    total_cash = 0.0
    total_bank = 0.0
    
    for company in companies:
        # Суммируем балансы счетов компании
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

# ===================== НОВЫЕ ЭНДПОИНТЫ ДЛЯ ОТЧЁТОВ =====================

@router.get("/dynamics")
async def get_dynamics(
    company_id: int,
    start_date: datetime,
    end_date: datetime,
    interval: str = "day",
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
    
    # Приводим даты к naive (без часового пояса)
    if start_date.tzinfo is not None:
        start_date = start_date.replace(tzinfo=None)
    if end_date.tzinfo is not None:
        end_date = end_date.replace(tzinfo=None)
    
    # Используем cast для преобразования даты
    if interval == 'day':
        date_trunc = func.date_trunc('day', Transaction.date)
    elif interval == 'week':
        date_trunc = func.date_trunc('week', Transaction.date)
    else:
        date_trunc = func.date_trunc('month', Transaction.date)
    
    # Доходы
    income_query = select(
        date_trunc.label("period"),
        func.sum(Transaction.amount).label("total")
    ).where(
        Transaction.company_id == company_id,
        Transaction.type == 'income',
        Transaction.is_deleted == False,
        Transaction.date >= start_date,
        Transaction.date <= end_date
    ).group_by(date_trunc).order_by(date_trunc)
    
    # Расходы
    expense_query = select(
        date_trunc.label("period"),
        func.sum(Transaction.amount).label("total")
    ).where(
        Transaction.company_id == company_id,
        Transaction.type == 'expense',
        Transaction.is_deleted == False,
        Transaction.date >= start_date,
        Transaction.date <= end_date
    ).group_by(date_trunc).order_by(date_trunc)
    
    income_result = await db.execute(income_query)
    expense_result = await db.execute(expense_query)
    
    income_map = {row.period.strftime('%Y-%m-%d'): float(row.total) for row in income_result}
    expense_map = {row.period.strftime('%Y-%m-%d'): float(row.total) for row in expense_result}
    
    all_periods = sorted(set(income_map.keys()) | set(expense_map.keys()))
    
    result = []
    for period in all_periods:
        inc = income_map.get(period, 0)
        exp = expense_map.get(period, 0)
        result.append({
            "period": period,
            "income": inc,
            "expense": exp,
            "profit": inc - exp
        })
    
    return result


@router.get("/income-by-category")
async def get_income_by_category(
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
    # Проверка доступа (аналогично)
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="Access denied")
    
    query = select(
        Category.id.label("category_id"),
        Category.name.label("category_name"),
        func.coalesce(func.sum(Transaction.amount), 0).label("total")
    ).outerjoin(
        Transaction, and_(
            Transaction.category_id == Category.id,
            Transaction.company_id == company_id,
            Transaction.type == 'income',
            Transaction.is_deleted == False,
            Transaction.date >= start_date,
            Transaction.date <= end_date
        )
    ).where(
        Category.company_id == company_id,
        Category.type == 'income'
    ).group_by(Category.id, Category.name).order_by(func.sum(Transaction.amount).desc())
    
    result = await db.execute(query)
    rows = result.all()
    return [{"category_id": r.category_id, "category_name": r.category_name, "total": float(r.total)} for r in rows]


@router.get("/expense-by-category")
async def get_expense_by_category(
    company_id: int,
    start_date: datetime,
    end_date: datetime,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Аналогично, но для расходов
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="Access denied")
    
    query = select(
        Category.id.label("category_id"),
        Category.name.label("category_name"),
        func.coalesce(func.sum(Transaction.amount), 0).label("total")
    ).outerjoin(
        Transaction, and_(
            Transaction.category_id == Category.id,
            Transaction.company_id == company_id,
            Transaction.type == 'expense',
            Transaction.is_deleted == False,
            Transaction.date >= start_date,
            Transaction.date <= end_date
        )
    ).where(
        Category.company_id == company_id,
        Category.type == 'expense'
    ).group_by(Category.id, Category.name).order_by(func.sum(Transaction.amount).desc())
    
    result = await db.execute(query)
    rows = result.all()
    return [{"category_id": r.category_id, "category_name": r.category_name, "total": float(r.total)} for r in rows]


@router.get("/cash-vs-noncash")
async def get_cash_vs_noncash(
    company_id: int,
    start_date: datetime,
    end_date: datetime,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Приводим даты к naive (без часового пояса)
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
    
    # Получаем ID счетов "Наличные" и "Банк" (или по типу)
    cash_query = select(func.sum(Transaction.amount)).where(
        Transaction.company_id == company_id,
        Transaction.is_deleted == False,
        Transaction.date >= start_date,
        Transaction.date <= end_date,
        Transaction.account.has(type='cash')
    )
    bank_query = select(func.sum(Transaction.amount)).where(
        Transaction.company_id == company_id,
        Transaction.is_deleted == False,
        Transaction.date >= start_date,
        Transaction.date <= end_date,
        Transaction.account.has(type='bank')
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
    sort_by: str = "quantity",  # 'quantity' или 'amount'
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
    
    # Агрегация по товарам из transaction_items, связанных с доходами
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
    ).where(
        Transaction.company_id == company_id,
        Transaction.type == 'income',
        Transaction.is_deleted == False,
        Transaction.date >= start_date,
        Transaction.date <= end_date
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
    sort_by: str = "quantity",  # 'quantity' или 'amount'
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
    
    # Сначала получаем все продажи витрины (транзакции с showcase_item_id)
    # Нам нужно сгруппировать по showcase_item_id, но количество товара не хранится напрямую в транзакции.
    # Мы можем либо добавить поле quantity в Transaction (не делали), либо считать количество из рецепта.
    # В упрощённом варианте будем считать каждую продажу витрины за 1 штуку (quantity = 1) и сумму = amount.
    # Потом можно будет доработать.
    query = select(
        ShowcaseItem.id.label("showcase_item_id"),
        ShowcaseItem.name.label("name"),
        func.count(Transaction.id).label("quantity"),
        func.sum(Transaction.amount).label("amount")
    ).select_from(
        Transaction
    ).join(
        ShowcaseItem, Transaction.showcase_item_id == ShowcaseItem.id
    ).where(
        Transaction.company_id == company_id,
        Transaction.type == 'income',
        Transaction.is_deleted == False,
        Transaction.date >= start_date,
        Transaction.date <= end_date,
        Transaction.showcase_item_id.isnot(None)
    ).group_by(ShowcaseItem.id, ShowcaseItem.name)
    
    if sort_by == 'quantity':
        query = query.order_by(func.count(Transaction.id).desc())
    else:
        query = query.order_by(func.sum(Transaction.amount).desc())
    
    result = await db.execute(query)
    rows = result.all()
    return [
        {
            "showcase_item_id": r.showcase_item_id,
            "name": r.name,
            "quantity": r.quantity,
            "amount": float(r.amount)
        }
        for r in rows
    ]