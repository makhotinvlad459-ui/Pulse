import json
import uuid
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import httpx
from pydantic import BaseModel

from app.database import get_db
from app.models import User, Company, UserRole, PaymentOrder
from app.deps import get_current_user
from app.config import settings

router = APIRouter(prefix="/subscription", tags=["subscription"], redirect_slashes=False)

PRICES = {
    "monthly": 480,
    "half_year": 2400,
    "yearly": 4000,
    "extra_company": 250,
}

class PaymentCreateRequest(BaseModel):
    plan: str

@router.get("/status")
async def get_subscription_status(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.founder_id == current_user.id))
        companies = result.scalars().all()
        companies_count = len(companies)
    else:
        companies_count = 0

    remaining_free_companies = max(0, 3 + (current_user.extra_companies or 0) - companies_count)
    has_active_subscription = current_user.subscription_until and current_user.subscription_until > datetime.utcnow()

    return {
        "has_active_subscription": has_active_subscription,
        "subscription_plan": current_user.subscription_plan,
        "subscription_expires_at": current_user.subscription_until.isoformat() if current_user.subscription_until else None,
        "companies_count": companies_count,
        "free_companies_limit": 3 + (current_user.extra_companies or 0),
        "remaining_free_companies": remaining_free_companies,
        "can_create_company": (companies_count < 3 + (current_user.extra_companies or 0)) or has_active_subscription,
        "limits": {
            "transactions": 50,
            "messages": 50,
            "tasks": 50,
            "orders": 50,
        }
    }

@router.post("/create-payment")
async def create_payment(
    req: PaymentCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    plan = req.plan
    if plan not in PRICES:
        raise HTTPException(400, "Invalid plan")

    if plan == "extra_company":
        amount = PRICES["extra_company"]
    else:
        base_amount = PRICES[plan]
        extra_count = current_user.extra_companies or 0
        extra_amount = extra_count * 250
        amount = base_amount + extra_amount

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
        user.extra_companies = (user.extra_companies or 0) + 1
    else:
        # Продление подписки
        if plan == "monthly":
            delta = timedelta(days=30)
        elif plan == "half_year":
            delta = timedelta(days=180)
        else:  # yearly
            delta = timedelta(days=365)
        if user.subscription_until and user.subscription_until > now:
            user.subscription_until = user.subscription_until + delta
        else:
            user.subscription_until = now + delta
        user.subscription_plan = plan
        # extra_companies не сбрасываются

    await db.commit()
    return {"status": "ok"}

@router.post("/ios/verify-receipt")
async def verify_apple_receipt(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return {"detail": "iOS receipts not yet implemented"}