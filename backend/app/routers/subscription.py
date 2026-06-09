import json
import uuid
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
import httpx
from pydantic import BaseModel

from app.database import get_db
from app.models import User, Company, UserRole, PaymentOrder
from app.deps import get_current_user
from app.config import settings
from app.services.subscription_limits import FREE_LIMITS, get_company_limit_info

router = APIRouter(prefix="/subscription", tags=["subscription"], redirect_slashes=False)

# Новая структура цен
SUBSCRIPTION_PRICES = {
    "monthly": 500,      # базовая подписка (2 компании)
    "extra_company": 250  # каждая доп. компания
}

class PaymentCreateRequest(BaseModel):
    plan: str  # "monthly", "extra_company"

@router.get("/status")
async def get_subscription_status(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    from app.services.subscription_limits import get_company_limit_info
    
    # Получаем количество компаний пользователя
    result = await db.execute(
        select(func.count(Company.id))
        .where(Company.founder_id == current_user.id)
    )
    companies_count = result.scalar() or 0
    
    # Получаем общую информацию о лимитах
    limits = await get_company_limit_info(db, current_user)
    
    has_active = current_user.subscription_until and current_user.subscription_until > datetime.utcnow()
    
    return {
        "has_active_subscription": has_active,
        "subscription_plan": current_user.subscription_plan,
        "subscription_expires_at": current_user.subscription_until.isoformat() if current_user.subscription_until else None,
        "companies_count": companies_count,
        "companies_limit": limits["companies_limit"],
        "remaining_companies": limits["remaining_companies"],
        "extra_companies": limits["extra_companies"],
        "next_payment_amount": limits["next_payment_amount"],
        "transactions_used": limits["transactions_used"],
        "transactions_limit": limits["transactions_limit"],
        "messages_used": limits["messages_used"],
        "messages_limit": limits["messages_limit"],
        "remaining_transactions": limits["remaining_transactions"],
        "remaining_messages": limits["remaining_messages"],
        "can_create_transaction": has_active or limits["remaining_transactions"] > 0,
        "can_create_message": has_active or limits["remaining_messages"] > 0,
        "can_create_company": has_active or limits["remaining_companies"] > 0,
    }

@router.post("/create-payment")
async def create_payment(
    req: PaymentCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    plan = req.plan
    
    if plan == "monthly":
        # Расчёт суммы с учётом extra_companies
        extra_count = current_user.extra_companies or 0
        amount = SUBSCRIPTION_PRICES["monthly"] + (extra_count * SUBSCRIPTION_PRICES["extra_company"])
    elif plan == "extra_company":
        amount = SUBSCRIPTION_PRICES["extra_company"]
    else:
        raise HTTPException(400, "Invalid plan")

    payment_order = PaymentOrder(
        user_id=current_user.id,
        plan=plan,
        amount=amount,
        status="pending"
    )
    db.add(payment_order)
    await db.flush()
    order_db_id = payment_order.id

    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://api.yookassa.ru/v3/payments",
            json={
                "amount": {"value": amount, "currency": "RUB"},
                "confirmation": {
                    "type": "redirect",
                    "return_url": settings.FRONTEND_URL + "/payment-complete",
                },
                "capture": True,
                "description": f"Подписка {plan} для пользователя {current_user.email}",
                "metadata": {
                    "user_id": current_user.id,
                    "plan": plan,
                    "order_id": order_db_id,
                }
            },
            auth=(settings.YOOKASSA_SHOP_ID, settings.YOOKASSA_SECRET_KEY)
        )
        data = response.json()
        if response.status_code != 200:
            raise HTTPException(400, f"YooKassa error: {data}")

        payment_id = data.get("id")
        confirmation_url = data["confirmation"]["confirmation_url"]

        payment_order.payment_id = payment_id
        await db.commit()

    return {"confirmation_url": confirmation_url, "order_id": order_db_id}

@router.post("/webhook")
async def yookassa_webhook(request: Request, db: AsyncSession = Depends(get_db)):
    payload = await request.json()
    event = payload.get("event")
    if event != "payment.succeeded":
        return {"status": "ignored"}

    payment = payload["object"]
    payment_id = payment["id"]
    metadata = payment["metadata"]
    plan = metadata["plan"]
    user_id = int(metadata["user_id"])
    amount = float(payment["amount"]["value"])

    result = await db.execute(
        select(PaymentOrder).where(
            PaymentOrder.payment_id == payment_id,
            PaymentOrder.user_id == user_id,
            PaymentOrder.plan == plan
        )
    )
    order = result.scalar_one_or_none()
    if not order or order.status != "pending":
        return {"status": "ignored"}

    order.status = "paid"
    order.updated_at = datetime.utcnow()

    user = await db.get(User, user_id)
    if not user:
        return {"status": "user not found"}

    now = datetime.utcnow()
    
    if plan == "extra_company":
        # Добавляем дополнительную компанию навсегда
        user.extra_companies = (user.extra_companies or 0) + 1
    elif plan == "monthly":
        # Продление базовой подписки на месяц
        delta = timedelta(days=30)
        if user.subscription_until and user.subscription_until > now:
            user.subscription_until = user.subscription_until + delta
        else:
            user.subscription_until = now + delta
        user.subscription_plan = "monthly"
        # extra_companies НЕ сбрасываются!

    await db.commit()
    return {"status": "ok"}

@router.post("/ios/verify-receipt")
async def verify_apple_receipt(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return {"detail": "iOS receipts not yet implemented"}