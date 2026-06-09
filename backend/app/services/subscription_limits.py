from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from app.models import Transaction, ChatMessage, Company, User

FREE_LIMITS = {
    "transactions": 40,   # всего за всё время
    "messages": 40,       # всего за всё время
    "base_companies": 2,  # базово 2 компании
}

async def get_total_transactions_count(
    db: AsyncSession,
    user_id: int
) -> int:
    """Общее количество транзакций пользователя по ВСЕМ его компаниям"""
    # Сначала получаем все компании пользователя
    companies_result = await db.execute(
        select(Company.id).where(Company.founder_id == user_id)
    )
    company_ids = [row[0] for row in companies_result.all()]
    
    if not company_ids:
        return 0
    
    result = await db.execute(
        select(func.count(Transaction.id))
        .where(
            Transaction.company_id.in_(company_ids),
            Transaction.is_deleted == False
        )
    )
    return result.scalar() or 0

async def get_total_messages_count(
    db: AsyncSession,
    user_id: int
) -> int:
    """Общее количество сообщений пользователя по ВСЕМ его компаниям"""
    companies_result = await db.execute(
        select(Company.id).where(Company.founder_id == user_id)
    )
    company_ids = [row[0] for row in companies_result.all()]
    
    if not company_ids:
        return 0
    
    result = await db.execute(
        select(func.count(ChatMessage.id))
        .where(ChatMessage.company_id.in_(company_ids))
    )
    return result.scalar() or 0

async def check_transaction_limit(
    db: AsyncSession,
    user: User
) -> tuple[bool, int, int]:
    """
    Проверяет лимит транзакций (всего за всё время).
    Возвращает: (can_create, used, limit)
    """
    used = await get_total_transactions_count(db, user.id)
    limit = FREE_LIMITS["transactions"]
    
    # Если есть активная подписка — безлимит
    has_active = user.subscription_until and user.subscription_until > datetime.utcnow()
    
    if has_active:
        return True, used, limit
    return used < limit, used, limit

async def check_message_limit(
    db: AsyncSession,
    user: User
) -> tuple[bool, int, int]:
    """
    Проверяет лимит сообщений (всего за всё время).
    Возвращает: (can_create, used, limit)
    """
    used = await get_total_messages_count(db, user.id)
    limit = FREE_LIMITS["messages"]
    
    has_active = user.subscription_until and user.subscription_until > datetime.utcnow()
    
    if has_active:
        return True, used, limit
    return used < limit, used, limit

async def get_company_limit_info(
    db: AsyncSession,
    user: User
) -> dict:
    """
    Полная информация о лимитах пользователя
    """
    # Считаем компании
    result = await db.execute(
        select(func.count(Company.id))
        .where(Company.founder_id == user.id)
    )
    companies_count = result.scalar() or 0
    
    extra = user.extra_companies or 0
    companies_limit = FREE_LIMITS["base_companies"] + extra
    
    # Следующий платёж
    next_payment = 500 + (extra * 250)  # 500 база + 250 за каждую доп компанию
    
    has_active = user.subscription_until and user.subscription_until > datetime.utcnow()
    
    # Получаем использованные транзакции и сообщения
    transactions_used = await get_total_transactions_count(db, user.id)
    messages_used = await get_total_messages_count(db, user.id)
    
    return {
        "companies_used": companies_count,
        "companies_limit": companies_limit,
        "remaining_companies": max(0, companies_limit - companies_count),
        "extra_companies": extra,
        "next_payment_amount": next_payment,
        "has_active_subscription": has_active,
        "subscription_expires_at": user.subscription_until,
        "transactions_used": transactions_used,
        "transactions_limit": FREE_LIMITS["transactions"],
        "messages_used": messages_used,
        "messages_limit": FREE_LIMITS["messages"],
        "remaining_transactions": max(0, FREE_LIMITS["transactions"] - transactions_used),
        "remaining_messages": max(0, FREE_LIMITS["messages"] - messages_used),
    }