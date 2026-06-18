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

# Цены для ЮKassa (рубли)
SUBSCRIPTION_PRICES = {
    "monthly": 500,
    "half_year": 2700,
    "extra_company": 250
}

class PaymentCreateRequest(BaseModel):
    plan: str  # "monthly", "half_year", "extra_company"
    platform: str = "web"  # "web", "android", "ios"

class VerifyMobilePurchaseRequest(BaseModel):
    token: str  # purchaseToken от Google или receipt от Apple
    plan: str
    store: str  # "google" или "apple"
    product_id: str  # ID продукта из магазина

# ===================== СТАТУС ПОДПИСКИ =====================
@router.get("/status")
async def get_subscription_status(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    from app.services.subscription_limits import get_company_limit_info
    
    result = await db.execute(
        select(func.count(Company.id))
        .where(Company.founder_id == current_user.id)
    )
    companies_count = result.scalar() or 0
    
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

# ===================== WEB (ЮKassa) =====================
@router.post("/create-payment")
async def create_payment(
    req: PaymentCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Создание платежа через ЮKassa (только для Web)"""
    
    # Защита: мобильные платформы не должны использовать этот эндпоинт
    if req.platform != "web":
        raise HTTPException(
            status_code=400,
            detail="Mobile payments must use Google Play or App Store"
        )
    
    plan = req.plan
    has_active_subscription = current_user.subscription_until and current_user.subscription_until > datetime.utcnow()
    
    # Расчет суммы
    if plan == "monthly":
        extra_count = current_user.extra_companies or 0
        amount = SUBSCRIPTION_PRICES["monthly"] + (extra_count * SUBSCRIPTION_PRICES["extra_company"])
    elif plan == "half_year":
        extra_count = current_user.extra_companies or 0
        amount = 2700 + (extra_count * 250 * 6)   # 250 в месяц × 6 месяцев
    elif plan == "extra_company":
        if not has_active_subscription:
            raise HTTPException(
                status_code=400,
                detail="ERROR_NEED_BASE_SUBSCRIPTION"
            )
        amount = SUBSCRIPTION_PRICES["extra_company"]
    else:
        raise HTTPException(
            status_code=400,
            detail="ERROR_INVALID_PLAN"
        )

    # Создаем запись о платеже
    payment_order = PaymentOrder(
        user_id=current_user.id,
        plan=plan,
        amount=amount,
        status="pending",
        platform="web"  # <-- указываем платформу
    )
    db.add(payment_order)
    await db.flush()
    order_db_id = payment_order.id

    idempotence_key = str(uuid.uuid4())

    # Запрос к ЮKassa
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
            auth=(settings.YOOKASSA_SHOP_ID, settings.YOOKASSA_SECRET_KEY),
            headers={"Idempotence-Key": idempotence_key}
        )
        data = response.json()
        if response.status_code != 200:
            raise HTTPException(400, f"YooKassa error: {data}")

        payment_id = data.get("id")
        confirmation_url = data["confirmation"]["confirmation_url"]

        payment_order.payment_id = payment_id
        await db.commit()

    return {"confirmation_url": confirmation_url, "order_id": order_db_id}

# ===================== WEBHOOK ЮKassa =====================
@router.post("/webhook")
async def yookassa_webhook(request: Request, db: AsyncSession = Depends(get_db)):
    """Webhook от ЮKassa для подтверждения оплаты"""
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
            PaymentOrder.plan == plan,
            PaymentOrder.platform == "web"  # <-- только для веб-платежей
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

    # Активируем подписку
    await _activate_subscription(db, user, plan)

    await db.commit()
    return {"status": "ok"}

# ===================== МОБИЛЬНЫЕ ПЛАТЕЖИ =====================
@router.post("/verify-mobile")
async def verify_mobile_purchase(
    req: VerifyMobilePurchaseRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Верификация покупок из Google Play или App Store
    Вызывается из мобильного приложения после успешной покупки
    """
    
    # Проверяем, что пользователь не пытается купить то же самое дважды
    existing_order = await db.execute(
        select(PaymentOrder).where(
            PaymentOrder.user_id == current_user.id,
            PaymentOrder.plan == req.plan,
            PaymentOrder.platform == req.store,
            PaymentOrder.status == "pending"
        )
    )
    if existing_order.scalar_one_or_none():
        # Если уже есть pending заказ, проверяем не был ли он уже оплачен
        pass
    
    # Верифицируем покупку в зависимости от магазина
    if req.store == "google":
        await _verify_google_purchase(req.token, req.product_id, current_user)
    elif req.store == "apple":
        await _verify_apple_purchase(req.token, req.product_id, current_user)
    else:
        raise HTTPException(status_code=400, detail="Unknown store")

    # Создаем запись о платеже
    payment_order = PaymentOrder(
        user_id=current_user.id,
        plan=req.plan,
        amount=0,  # Сумма не хранится, т.к. платеж через магазин
        status="paid",
        payment_id=req.token,  # Сохраняем токен для истории
        platform=req.store,  # "google" или "apple"
    )
    db.add(payment_order)

    # Активируем подписку
    await _activate_subscription(db, current_user, req.plan)

    await db.commit()
    return {"status": "ok"}

# ===================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ =====================

async def _verify_google_purchase(token: str, product_id: str, user: User):
    """
    Верификация покупки в Google Play
    TODO: Реализовать через Google Play Developer API
    """
    # ВРЕМЕННАЯ ЗАГЛУШКА - пока просто пропускаем
    # В продакшене нужно реально проверять через API
    
    # Пример реальной проверки:
    # 1. Получить access_token для Service Account
    # 2. Сделать запрос к:
    # https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{packageName}/purchases/products/{productId}/tokens/{token}
    # 3. Проверить, что purchaseState = 0 (куплено)
    # 4. Проверить, что consumptionState = 0 (не потреблено, если consumable)
    
    # Пока возвращаем True для тестирования
    return True

async def _verify_apple_purchase(receipt: str, product_id: str, user: User):
    """
    Верификация покупки в App Store
    TODO: Реализовать через Apple App Store Server API
    """
    # ВРЕМЕННАЯ ЗАГЛУШКА - пока просто пропускаем
    
    # Пример реальной проверки:
    # 1. Отправить receipt на https://buy.itunes.apple.com/verifyReceipt (production)
    #    или https://sandbox.itunes.apple.com/verifyReceipt (sandbox)
    # 2. Проверить status = 0
    # 3. Найти в receipt нужный product_id
    # 4. Проверить expires_date для подписок
    
    return True

async def _activate_subscription(db: AsyncSession, user: User, plan: str):
    """Активация подписки или добавление дополнительной компании"""
    now = datetime.utcnow()
    
    if plan == "extra_company":
        # Добавляем одну компанию
        user.extra_companies = (user.extra_companies or 0) + 1
    elif plan == "monthly":
        delta = timedelta(days=30)
        if user.subscription_until and user.subscription_until > now:
            user.subscription_until = user.subscription_until + delta
        else:
            user.subscription_until = now + delta
        user.subscription_plan = "monthly"
    elif plan == "half_year":
        delta = timedelta(days=180)
        if user.subscription_until and user.subscription_until > now:
            user.subscription_until = user.subscription_until + delta
        else:
            user.subscription_until = now + delta
        user.subscription_plan = "half_year"
    else:
        raise HTTPException(status_code=400, detail="Unknown plan")
    
    await db.commit()

# ===================== iOS (устаревший, оставляем для совместимости) =====================
@router.post("/ios/verify-receipt")
async def verify_apple_receipt(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Устаревший эндпоинт для iOS.
    Используйте /verify-mobile с store="apple"
    """
    return {"detail": "Please use /verify-mobile endpoint with store='apple'"}