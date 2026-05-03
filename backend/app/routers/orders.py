from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, func, delete
from sqlalchemy.orm import selectinload
from typing import List, Optional
from datetime import datetime
from decimal import Decimal
import json
import os
import shutil

from app.database import get_db
from app.models import (
    User, Company, Order, OrderStatus, OrderItem, OrderPayment, OrderAttachment,
    Product, CompanyMember, Permission, CompanyMemberPermission, UserRole,
    StockWriteOff, Transaction, Account
)
from app.schemas import (
    OrderCreate, OrderUpdate, OrderResponse, OrderItemResponse, OrderPaymentResponse,
    OrderAttachmentResponse
)
from app.deps import get_current_user

router = APIRouter(prefix="/orders", tags=["orders"])

# ---------- Вспомогательные функции ----------

async def _check_company_access(company_id: int, current_user: User, db: AsyncSession) -> bool:
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
        if result.scalar_one_or_none():
            return True
    result = await db.execute(select(CompanyMember).where(CompanyMember.company_id == company_id, CompanyMember.user_id == current_user.id))
    return result.scalar_one_or_none() is not None

async def _has_permission(company_id: int, current_user: User, db: AsyncSession, perm_name: str) -> bool:
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
            Permission.name == perm_name
        )
    )
    return perm.scalar_one_or_none() is not None

async def _recalc_order_total(order_id: int, db: AsyncSession):
    order = await db.get(Order, order_id)
    if not order:
        return 0
    items_sum = await db.execute(select(func.sum(OrderItem.total)).where(OrderItem.order_id == order_id))
    total = float(order.work_price or 0) + float(items_sum.scalar() or 0.0)
    order.total_amount = total
    await db.flush()
    return total

async def _recalc_paid_amount(order_id: int, db: AsyncSession):
    order = await db.get(Order, order_id)
    if not order:
        return 0
    payments_sum = await db.execute(select(func.sum(OrderPayment.amount)).where(OrderPayment.order_id == order_id))
    payments_sum = float(payments_sum.scalar() or 0.0)
    items_paid = await db.execute(select(func.sum(OrderItem.total)).where(OrderItem.order_id == order_id, OrderItem.is_paid == True))
    items_paid_sum = float(items_paid.scalar() or 0.0)
    total_paid = payments_sum + items_paid_sum
    order.paid_amount = total_paid
    await db.flush()
    return total_paid

# ---------- GET / ----------
@router.get("/", response_model=List[OrderResponse])
async def get_orders(
    company_id: int,
    status: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    if not await _has_permission(company_id, current_user, db, "view_orders"):
        raise HTTPException(403, "No permission")
    query = select(Order).where(Order.company_id == company_id).options(
        selectinload(Order.assignee),
        selectinload(Order.items).selectinload(OrderItem.product),
        selectinload(Order.payments),
        selectinload(Order.attachments),
        selectinload(Order.creator), 
    )
    if status:
        query = query.where(Order.status == status)
    query = query.order_by(Order.created_at.desc())
    result = await db.execute(query)
    orders = result.scalars().all()
    response = []
    for o in orders:
        items = [
            OrderItemResponse(
                id=i.id,
                product_id=i.product_id,
                product_name=i.product.name,
                quantity=float(i.quantity),
                unit_price=float(i.unit_price),
                use_from_stock=i.use_from_stock,
                total=float(i.total),
                is_paid=i.is_paid,
            ) for i in o.items
        ]
        payments = [
            OrderPaymentResponse(
                id=p.id,
                amount=float(p.amount),
                payment_date=p.payment_date,
                comment=p.comment,
                attachment_urls=json.loads(p.attachment_urls) if p.attachment_urls else None
            ) for p in o.payments
        ]
        attachments = [
            OrderAttachmentResponse(
                id=a.id,
                file_url=a.file_url,
                uploaded_by=a.uploaded_by,
                uploaded_at=a.uploaded_at
            ) for a in o.attachments
        ]
        response.append(OrderResponse(
            id=o.id,
            company_id=o.company_id,
            title=o.title,
            description=o.description,
            status=o.status.value,
            total_amount=float(o.total_amount),
            paid_amount=float(o.paid_amount),
            work_price=float(o.work_price or 0),
            assignee_id=o.assignee_id,
            assignee_name=o.assignee.display_name if o.assignee else None,
            created_by=o.created_by,
            creator_name=o.creator.display_name,
            created_at=o.created_at,
            updated_at=o.updated_at,
            deadline=o.deadline,
            items=items,
            payments=payments,
            attachments=attachments
        ))
    return response

# ---------- GET /{order_id} ----------
@router.get("/{order_id}", response_model=OrderResponse)
async def get_order(
    order_id: int,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    if not await _has_permission(company_id, current_user, db, "view_orders"):
        raise HTTPException(403, "No permission")
    result = await db.execute(
        select(Order).where(Order.id == order_id, Order.company_id == company_id).options(
            selectinload(Order.assignee),
            selectinload(Order.items).selectinload(OrderItem.product),
            selectinload(Order.payments),
            selectinload(Order.attachments),
            selectinload(Order.creator), 
        )
    )
    o = result.scalar_one_or_none()
    if not o:
        raise HTTPException(404, "Order not found")
    items = [
        OrderItemResponse(
            id=i.id,
            product_id=i.product_id,
            product_name=i.product.name,
            quantity=float(i.quantity),
            unit_price=float(i.unit_price),
            use_from_stock=i.use_from_stock,
            total=float(i.total),
            is_paid=i.is_paid,
        ) for i in o.items
    ]
    payments = [
        OrderPaymentResponse(
            id=p.id,
            amount=float(p.amount),
            payment_date=p.payment_date,
            comment=p.comment,
            attachment_urls=json.loads(p.attachment_urls) if p.attachment_urls else None
        ) for p in o.payments
    ]
    attachments = [
        OrderAttachmentResponse(
            id=a.id,
            file_url=a.file_url,
            uploaded_by=a.uploaded_by,
            uploaded_at=a.uploaded_at
        ) for a in o.attachments
    ]
    return OrderResponse(
        id=o.id,
        company_id=o.company_id,
        title=o.title,
        description=o.description,
        status=o.status.value,
        total_amount=float(o.total_amount),
        paid_amount=float(o.paid_amount),
        work_price=float(o.work_price or 0),
        assignee_id=o.assignee_id,
        assignee_name=o.assignee.display_name if o.assignee else None,
        created_by=o.created_by,
        creator_name=o.creator.display_name,
        created_at=o.created_at,
        updated_at=o.updated_at,
        deadline=o.deadline,
        items=items,
        payments=payments,
        attachments=attachments
    )

# ---------- POST / ----------
@router.post("/", response_model=OrderResponse)
async def create_order(
    company_id: int,
    order_data: OrderCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    if not await _has_permission(company_id, current_user, db, "edit_orders"):
        raise HTTPException(403, "No permission")
    new_order = Order(
        company_id=company_id,
        title=order_data.title,
        description=order_data.description,
        work_price=order_data.work_price or 0,
        assignee_id=order_data.assignee_id,
        deadline=order_data.deadline,
        created_by=current_user.id,
        status=OrderStatus.PENDING,
        total_amount=0,
        paid_amount=0
    )
    db.add(new_order)
    await db.flush()
    total_materials = 0
    for item_data in order_data.items:
        product = await db.execute(select(Product).where(Product.id == item_data.product_id, Product.company_id == company_id))
        product = product.scalar_one_or_none()
        if not product:
            raise HTTPException(404, f"Product {item_data.product_id} not found")
        item_total = float(item_data.quantity) * float(item_data.unit_price)
        order_item = OrderItem(
            order_id=new_order.id,
            product_id=item_data.product_id,
            quantity=item_data.quantity,
            unit_price=item_data.unit_price,
            use_from_stock=item_data.use_from_stock,
            total=item_total,
            is_paid=item_data.is_paid or False,
        )
        db.add(order_item)
        total_materials += item_total
    new_order.total_amount = (new_order.work_price or 0) + total_materials
    await db.commit()
    await db.refresh(new_order)
    result = await db.execute(
        select(Order).where(Order.id == new_order.id).options(
            selectinload(Order.assignee),
            selectinload(Order.items).selectinload(OrderItem.product),
            selectinload(Order.creator),
        )
    )
    new_order = result.scalar_one()
    items = [
        OrderItemResponse(
            id=i.id,
            product_id=i.product_id,
            product_name=i.product.name,
            quantity=float(i.quantity),
            unit_price=float(i.unit_price),
            use_from_stock=i.use_from_stock,
            total=float(i.total),
            is_paid=i.is_paid,
        ) for i in new_order.items
    ]
    return OrderResponse(
        id=new_order.id,
        company_id=new_order.company_id,
        title=new_order.title,
        description=new_order.description,
        status=new_order.status.value,
        total_amount=float(new_order.total_amount),
        paid_amount=float(new_order.paid_amount),
        work_price=float(new_order.work_price or 0),
        assignee_id=new_order.assignee_id,
        assignee_name=new_order.assignee.display_name if new_order.assignee else None,
        created_by=new_order.created_by,
        creator_name=new_order.creator.display_name,
        created_at=new_order.created_at,
        updated_at=new_order.updated_at,
        deadline=new_order.deadline,
        items=items,
        payments=[],
        attachments=[]
    )

# ---------- PATCH /{order_id} ----------
@router.patch("/{order_id}", response_model=OrderResponse)
async def update_order(
    order_id: int,
    company_id: int,
    order_data: OrderUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    result = await db.execute(select(Order).where(Order.id == order_id, Order.company_id == company_id))
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(404, "Order not found")
    if order.status not in (OrderStatus.PENDING, OrderStatus.ACCEPTED):
        raise HTTPException(400, "Only pending/accepted orders can be updated")
    if not await _has_permission(company_id, current_user, db, "edit_orders"):
        raise HTTPException(403, "No permission")
    if order_data.title is not None: order.title = order_data.title
    if order_data.description is not None: order.description = order_data.description
    if order_data.work_price is not None: order.work_price = order_data.work_price
    if order_data.assignee_id is not None: order.assignee_id = order_data.assignee_id
    if order_data.deadline is not None: order.deadline = order_data.deadline
    if order_data.items is not None:
        await db.execute(delete(OrderItem).where(OrderItem.order_id == order_id))
        total_materials = 0
        for item_data in order_data.items:
            product = await db.execute(select(Product).where(Product.id == item_data.product_id, Product.company_id == company_id))
            product = product.scalar_one_or_none()
            if not product:
                raise HTTPException(404, f"Product {item_data.product_id} not found")
            item_total = float(item_data.quantity) * float(item_data.unit_price)
            order_item = OrderItem(
                order_id=order.id,
                product_id=item_data.product_id,
                quantity=item_data.quantity,
                unit_price=item_data.unit_price,
                use_from_stock=item_data.use_from_stock,
                total=item_total,
                is_paid=item_data.is_paid or False,
            )
            db.add(order_item)
            total_materials += item_total
        order.total_amount = (order.work_price or 0) + total_materials
    else:
        await _recalc_order_total(order_id, db)
    order.updated_at = datetime.utcnow()
    await db.commit()
    result = await db.execute(
        select(Order).where(Order.id == order_id).options(
            selectinload(Order.assignee),
            selectinload(Order.items).selectinload(OrderItem.product),
            selectinload(Order.payments),
            selectinload(Order.attachments),
            selectinload(Order.creator),
        )
    )
    order = result.scalar_one()
    items = [
        OrderItemResponse(
            id=i.id,
            product_id=i.product_id,
            product_name=i.product.name,
            quantity=float(i.quantity),
            unit_price=float(i.unit_price),
            use_from_stock=i.use_from_stock,
            total=float(i.total),
            is_paid=i.is_paid,
        ) for i in order.items
    ]
    payments = [
        OrderPaymentResponse(
            id=p.id,
            amount=float(p.amount),
            payment_date=p.payment_date,
            comment=p.comment,
            attachment_urls=json.loads(p.attachment_urls) if p.attachment_urls else None
        ) for p in order.payments
    ]
    attachments = [
        OrderAttachmentResponse(
            id=a.id,
            file_url=a.file_url,
            uploaded_by=a.uploaded_by,
            uploaded_at=a.uploaded_at
        ) for a in order.attachments
    ]
    return OrderResponse(
        id=order.id,
        company_id=order.company_id,
        title=order.title,
        description=order.description,
        status=order.status.value,
        total_amount=float(order.total_amount),
        paid_amount=float(order.paid_amount),
        work_price=float(order.work_price or 0),
        assignee_id=order.assignee_id,
        assignee_name=order.assignee.display_name if order.assignee else None,
        created_by=order.created_by,
        creator_name=order.creator.display_name,
        created_at=order.created_at,
        updated_at=order.updated_at,
        deadline=order.deadline,
        items=items,
        payments=payments,
        attachments=attachments
    )

# ---------- DELETE /{order_id} ----------
@router.delete("/{order_id}")
async def delete_order(
    order_id: int,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    order = await db.get(Order, order_id)
    if not order or order.company_id != company_id:
        raise HTTPException(404, "Order not found")
    if not await _has_permission(company_id, current_user, db, "edit_orders"):
        raise HTTPException(403, "No permission")
    # Удаляем заказ (и все связанные материалы, оплаты, вложения каскадно)
    await db.delete(order)
    await db.commit()
    return {"detail": "Order deleted"}

# ---------- POST /{order_id}/status ----------
@router.post("/{order_id}/status")
async def update_order_status(
    order_id: int,
    company_id: int,
    request: dict,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    status_value = request.get("status")
    if not status_value:
        raise HTTPException(400, "Missing status field")
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    order = await db.get(Order, order_id)
    if not order or order.company_id != company_id:
        raise HTTPException(404, "Order not found")
    if status_value not in ['accepted', 'completed', 'failed']:
        raise HTTPException(400, "Invalid status")
    if status_value == 'accepted' and not await _has_permission(company_id, current_user, db, "edit_orders"):
        raise HTTPException(403, "No permission to accept")
    if status_value == 'completed' and not await _has_permission(company_id, current_user, db, "edit_orders"):
        raise HTTPException(403, "No permission to complete")
    if status_value == 'failed' and not await _has_permission(company_id, current_user, db, "edit_orders"):
        raise HTTPException(403, "No permission to fail")
    if status_value == 'accepted' and order.status != OrderStatus.PENDING:
        raise HTTPException(400, "Only pending can be accepted")
    if status_value == 'completed' and order.status != OrderStatus.ACCEPTED:
        raise HTTPException(400, "Only accepted can be completed")
    if status_value == 'failed' and order.status not in (OrderStatus.PENDING, OrderStatus.ACCEPTED):
        raise HTTPException(400, "Only pending/accepted can be failed")
    if status_value == 'completed':
        cash_acc = await db.execute(select(Account).where(Account.company_id == company_id, Account.type == 'cash'))
        cash_acc = cash_acc.scalar_one_or_none()
        if not cash_acc:
            raise HTTPException(400, "No cash account")
        await db.refresh(order, attribute_names=['items'])
        for item in order.items:
            if item.use_from_stock:
                prod = await db.get(Product, item.product_id)
                if prod.current_quantity < item.quantity:
                    print(f"Warning: insufficient stock for {prod.name}")
                prod.current_quantity -= item.quantity
                write_off = StockWriteOff(
                    company_id=company_id,
                    product_id=item.product_id,
                    quantity=item.quantity,
                    reason="order_completion",
                    description=f"Списание по заказу {order.id}",
                    created_by=current_user.id
                )
                db.add(write_off)
        last_num = await db.execute(select(func.max(Transaction.number)).where(Transaction.company_id == company_id))
        last_num = last_num.scalar() or 0
        new_number = last_num + 1
        tx = Transaction(
            company_id=company_id,
            account_id=cash_acc.id,
            type='income',
            amount=order.total_amount,
            date=datetime.utcnow(),
            description=f"Выполнение заказа #{order.id} - {order.title}",
            created_by=current_user.id,
            number=new_number
        )
        db.add(tx)
    order.status = OrderStatus(status_value)
    order.updated_at = datetime.utcnow()
    await db.commit()
    return {"detail": f"Order status updated to {status_value}"}

# ---------- POST /{order_id}/items ----------
@router.post("/{order_id}/items")
async def add_order_item(
    order_id: int,
    company_id: int,
    item_data: dict,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    order = await db.get(Order, order_id)
    if not order or order.company_id != company_id:
        raise HTTPException(404, "Order not found")
    if order.status not in (OrderStatus.PENDING, OrderStatus.ACCEPTED):
        raise HTTPException(400, "Only pending/accepted orders can add items")
    if not await _has_permission(company_id, current_user, db, "edit_orders"):
        raise HTTPException(403, "No permission")
    product = await db.get(Product, item_data['product_id'])
    if not product or product.company_id != company_id:
        raise HTTPException(404, "Product not found")
    quantity = float(item_data['quantity'])
    unit_price = float(item_data['unit_price'])
    use_from_stock = item_data.get('use_from_stock', False)
    is_paid = item_data.get('is_paid', False)
    total = quantity * unit_price
    order_item = OrderItem(
        order_id=order_id,
        product_id=item_data['product_id'],
        quantity=quantity,
        unit_price=unit_price,
        use_from_stock=use_from_stock,
        total=total,
        is_paid=is_paid,
    )
    db.add(order_item)
    await db.flush()
    await _recalc_order_total(order_id, db)
    await _recalc_paid_amount(order_id, db)
    await db.commit()
    return {"detail": "Item added", "item_id": order_item.id}

# ---------- DELETE /items/{item_id} ----------
@router.delete("/items/{item_id}")
async def delete_order_item(
    item_id: int,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    item = await db.get(OrderItem, item_id, options=[selectinload(OrderItem.order)])
    if not item:
        raise HTTPException(404, "Item not found")
    if item.order.company_id != company_id:
        raise HTTPException(403, "Access denied")
    if item.order.status not in (OrderStatus.PENDING, OrderStatus.ACCEPTED):
        raise HTTPException(400, "Only pending/accepted orders can delete items")
    if not await _has_permission(company_id, current_user, db, "edit_orders"):
        raise HTTPException(403, "No permission")
    await db.delete(item)
    await db.flush()
    await _recalc_order_total(item.order_id, db)
    await _recalc_paid_amount(item.order_id, db)
    await db.commit()
    return {"detail": "Item deleted"}

# ---------- PATCH /items/{item_id} ----------
@router.patch("/items/{item_id}")
async def update_order_item(
    item_id: int,
    company_id: int,
    update_data: dict,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    item = await db.get(OrderItem, item_id, options=[selectinload(OrderItem.order)])
    if not item:
        raise HTTPException(404, "Item not found")
    if item.order.company_id != company_id:
        raise HTTPException(403, "Access denied")
    if item.order.status not in (OrderStatus.PENDING, OrderStatus.ACCEPTED):
        raise HTTPException(400, "Only pending/accepted orders can update items")
    if not await _has_permission(company_id, current_user, db, "edit_orders"):
        raise HTTPException(403, "No permission")
    if "unit_price" in update_data:
        item.unit_price = float(update_data["unit_price"])
        quantity = float(item.quantity)
        item.total = quantity * item.unit_price
    if "is_paid" in update_data:
        item.is_paid = update_data["is_paid"]
    await db.flush()
    await _recalc_order_total(item.order_id, db)
    await _recalc_paid_amount(item.order_id, db)
    await db.commit()
    return {"detail": "Item updated"}

# ---------- POST /{order_id}/payments ----------
@router.post("/{order_id}/payments")
async def add_payment(
    order_id: int,
    company_id: int,
    payment_data: dict,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    order = await db.get(Order, order_id)
    if not order or order.company_id != company_id:
        raise HTTPException(404, "Order not found")
    if not await _has_permission(company_id, current_user, db, "edit_orders"):
        raise HTTPException(403, "No permission")

    amount = payment_data.get("amount")
    date_str = payment_data.get("payment_date")
    comment = payment_data.get("comment", "")
    account_id = payment_data.get("account_id")
    counterparty = payment_data.get("counterparty", "")
    if not amount or not date_str or not account_id:
        raise HTTPException(400, "Missing amount, payment_date or account_id")
    try:
        payment_date = datetime.fromisoformat(date_str.replace("Z", "+00:00"))
    except:
        raise HTTPException(400, "Invalid date format")

    account = await db.get(Account, account_id)
    if not account or account.company_id != company_id:
        raise HTTPException(404, "Account not found")

    # номер транзакции
    last_num = await db.execute(select(func.max(Transaction.number)).where(Transaction.company_id == company_id))
    last_num = last_num.scalar() or 0
    new_number = last_num + 1

    # транзакция (доход)
    transaction = Transaction(
        company_id=company_id,
        account_id=account_id,
        type="income",
        amount=float(amount),
        date=payment_date,
        description=f"Оплата по заказу #{order.id} – {order.title}",
        created_by=current_user.id,
        number=new_number,
        counterparty=counterparty
    )
    db.add(transaction)
    await db.flush()

    # оплата в заказе
    payment = OrderPayment(
        order_id=order_id,
        amount=float(amount),
        payment_date=payment_date,
        comment=comment,
        transaction_id=transaction.id
    )
    db.add(payment)
    await db.flush()

    # обновляем баланс счёта
    account.balance += Decimal(str(amount))
    await _recalc_paid_amount(order_id, db)
    await db.commit()

    return {"detail": "Payment added", "payment_id": payment.id, "transaction_id": transaction.id}

# ---------- DELETE /{order_id}/payments/{payment_id} ----------
@router.delete("/{order_id}/payments/{payment_id}")
async def delete_payment(
    order_id: int,
    payment_id: int,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    if not await _has_permission(company_id, current_user, db, "edit_orders"):
        raise HTTPException(403, "No permission")
    payment = await db.get(OrderPayment, payment_id)
    if not payment or payment.order_id != order_id:
        raise HTTPException(404, "Payment not found")
    # удаляем связанную транзакцию
    if payment.transaction_id:
        transaction = await db.get(Transaction, payment.transaction_id)
        if transaction:
            # уменьшаем баланс счёта
            acc = await db.get(Account, transaction.account_id)
            if acc:
                acc.balance -= transaction.amount
            await db.delete(transaction)
    await db.delete(payment)
    await db.flush()
    await _recalc_paid_amount(order_id, db)
    await db.commit()
    return {"detail": "Payment deleted"}

# ---------- Вложения ----------
@router.post("/{order_id}/attachments")
async def add_attachment(
    order_id: int,
    company_id: int,
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    if not await _has_permission(company_id, current_user, db, "edit_orders"):
        raise HTTPException(403, "No permission")
    upload_dir = f"uploads/orders/{order_id}"
    os.makedirs(upload_dir, exist_ok=True)
    timestamp = int(datetime.utcnow().timestamp())
    safe_name = f"{timestamp}_{file.filename}"
    file_path = os.path.join(upload_dir, safe_name)
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    url = f"/uploads/orders/{order_id}/{safe_name}"
    att = OrderAttachment(order_id=order_id, file_url=url, uploaded_by=current_user.id)
    db.add(att)
    await db.commit()
    return {"detail": "Attachment added", "url": url}

@router.delete("/{order_id}/attachments/{attachment_id}")
async def delete_attachment(
    order_id: int,
    attachment_id: int,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    att = await db.get(OrderAttachment, attachment_id)
    if not att or att.order_id != order_id:
        raise HTTPException(404, "Attachment not found")
    if os.path.exists(att.file_url.lstrip('/')):
        os.remove(att.file_url.lstrip('/'))
    await db.delete(att)
    await db.commit()
    return {"detail": "Attachment deleted"}

# ---------- Получение сотрудников ----------
@router.get("/company/{company_id}/members")
async def get_company_members(
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    result = await db.execute(
        select(CompanyMember, User).join(User, CompanyMember.user_id == User.id)
        .where(CompanyMember.company_id == company_id)
    )
    members = []
    for member, user in result:
        members.append({
            "id": user.id,
            "full_name": user.display_name,
            "role_in_company": member.role_in_company,
        })
    return members