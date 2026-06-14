from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, func, delete
from typing import List, Optional
from datetime import datetime
from sqlalchemy.orm import selectinload
import os
from app.services.subscription_limits import check_transaction_limit
import shutil
from fastapi.responses import FileResponse
from decimal import Decimal
import uuid
from firebase_admin import storage

from app.database import get_db
from app.models import User, Company, Counterparty, Account, Category, Transaction, TransactionType, CompanyMember, UserRole, Product, TransactionItem, OrderPayment 
from app.schemas import TransactionCreate, TransactionResponse, TransactionItemResponse
from app.deps import get_current_user

router = APIRouter(prefix="/transactions", tags=["transactions"], redirect_slashes=False)

MAX_FILE_SIZE = 10 * 1024 * 1024
ALLOWED_EXTENSIONS = {'.jpg', '.jpeg', '.png', '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.txt'}

async def _normalize_counterparty(company_id: int, name: str | None, db: AsyncSession) -> str | None:
    """Приводит имя контрагента к существующему в БД написанию (без учёта регистра).
       Если контрагент не найден, возвращает исходное имя."""
    if not name:
        return None
   
    stmt = select(Transaction.counterparty).where(
        Transaction.company_id == company_id,
        func.lower(Transaction.counterparty) == name.lower(),
        Transaction.counterparty.isnot(None),
        Transaction.counterparty != ''
    ).limit(1)
    result = await db.execute(stmt)
    existing = result.scalar_one_or_none()
    return existing if existing else name

async def recalc_account_balance(account_id: int, db: AsyncSession):
    # Считаем только ОПЛАЧЕННЫЕ транзакции
    income = await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0))
        .where(
            Transaction.account_id == account_id,
            Transaction.type == 'income',
            Transaction.is_deleted == False,
            Transaction.is_paid == True
        )
    )
    total_income = float(income.scalar())
    
    expense = await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0))
        .where(
            Transaction.account_id == account_id,
            Transaction.type == 'expense',
            Transaction.is_deleted == False,
            Transaction.is_paid == True
        )
    )
    total_expense = float(expense.scalar())
    
    transfer_out = await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0))
        .where(
            Transaction.account_id == account_id,
            Transaction.type == 'transfer',
            Transaction.is_deleted == False,
            Transaction.is_paid == True
        )
    )
    total_transfer_out = float(transfer_out.scalar())
    
    transfer_in = await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0))
        .where(
            Transaction.transfer_to_account_id == account_id,
            Transaction.type == 'transfer',
            Transaction.is_deleted == False,
            Transaction.is_paid == True
        )
    )
    total_transfer_in = float(transfer_in.scalar())
    
    balance = total_income - total_expense - total_transfer_out + total_transfer_in
    await db.execute(update(Account).where(Account.id == account_id).values(balance=balance))

async def _recalc_paid_amount(order_id: int, db: AsyncSession):
    from app.models import Order, OrderItem
    order = await db.get(Order, order_id)
    if not order:
        return
    payments_sum = await db.execute(
        select(func.sum(OrderPayment.amount)).where(OrderPayment.order_id == order_id)
    )
    payments_sum = float(payments_sum.scalar() or 0.0)
    items_paid = await db.execute(
        select(func.sum(OrderItem.total)).where(OrderItem.order_id == order_id, OrderItem.is_paid == True)
    )
    items_paid_sum = float(items_paid.scalar() or 0.0)
    total_paid = payments_sum + items_paid_sum
    order.paid_amount = total_paid
    await db.flush()    

@router.post("/", response_model=TransactionResponse)
async def create_transaction(
    trans_data: TransactionCreate,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Проверка доступа к компании
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    # ========== ПРОВЕРКА ЛИМИТА ТРАНЗАКЦИЙ ==========
    can_create, used, limit = await check_transaction_limit(db, current_user)
    if not can_create:
        raise HTTPException(
            status_code=402,
            detail=f"Достигнут лимит бесплатных транзакций ({used}/{limit}). Оформите подписку для продолжения работы."
        )
    # =================================================
    
    # Проверка счёта
    result = await db.execute(select(Account).where(Account.id == trans_data.account_id, Account.company_id == company_id))
    account = result.scalar_one_or_none()
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")
    
    is_transfer = (trans_data.type.value == 'transfer')
    
    # ========== ДЛЯ ПЕРЕВОДА ==========
    if is_transfer:
        # Проверка счёта назначения
        if trans_data.transfer_to_account_id is None:
            raise HTTPException(status_code=400, detail="Transfer requires transfer_to_account_id")
        
        result = await db.execute(select(Account).where(Account.id == trans_data.transfer_to_account_id, Account.company_id == company_id))
        target_account = result.scalar_one_or_none()
        if not target_account:
            raise HTTPException(status_code=404, detail="Target account not found")
        if trans_data.account_id == trans_data.transfer_to_account_id:
            raise HTTPException(status_code=400, detail="Cannot transfer to the same account")
        
        # Для перевода не нужны категория и товары
        trans_data.category_id = None
        trans_data.items = []
    # ========== ДЛЯ ДОХОДА/РАСХОДА ==========
    else:
        if not trans_data.items and not trans_data.category_id:
            # Создание категории по умолчанию
            result = await db.execute(select(Category).where(Category.company_id == company_id, Category.is_system == True))
            default_cat = result.scalar_one_or_none()
            if not default_cat:
                default_cat = Category(
                    company_id=company_id,
                    name="Без категории",
                    type=trans_data.type.value,
                    is_system=True,
                    created_by=current_user.id
                )
                db.add(default_cat)
                await db.flush()
            trans_data.category_id = default_cat.id
        elif trans_data.category_id:
            result = await db.execute(select(Category).where(Category.id == trans_data.category_id, Category.company_id == company_id))
            if not result.scalar_one_or_none():
                raise HTTPException(status_code=404, detail="Category not found")
    
    # НОРМАЛИЗАЦИЯ КОНТРАГЕНТА
    normalized_counterparty = await _normalize_counterparty(company_id, trans_data.counterparty, db)
    
    if normalized_counterparty:
        existing_cp = await db.execute(
            select(Counterparty).where(
                Counterparty.company_id == company_id,
                func.lower(Counterparty.name) == normalized_counterparty.lower()
            )
        )
        if not existing_cp.scalar_one_or_none():
            new_cp = Counterparty(
                company_id=company_id,
                name=normalized_counterparty,
                inn=None,
                phone=None,
                director=None
            )
            db.add(new_cp)
            await db.flush()
    
    # Генерация номера операции
    last_num_result = await db.execute(select(func.max(Transaction.number)).where(Transaction.company_id == company_id))
    last_num = last_num_result.scalar() or 0
    new_number = last_num + 1
    
    # Приводим дату
    if trans_data.date.tzinfo is not None:
        trans_data.date = trans_data.date.replace(tzinfo=None)
    
    # Создаём транзакцию
    new_trans = Transaction(
        company_id=company_id,
        account_id=trans_data.account_id,
        type=trans_data.type.value,
        amount=trans_data.amount,
        date=trans_data.date,
        category_id=trans_data.category_id,
        description=trans_data.description,
        attachment_url=trans_data.attachment_url,
        created_by=current_user.id,
        transfer_to_account_id=trans_data.transfer_to_account_id if is_transfer else None,
        number=new_number,
        counterparty=normalized_counterparty,
        showcase_item_id=trans_data.showcase_item_id,
        quantity=trans_data.quantity,
        is_paid=trans_data.is_paid,
    )
    db.add(new_trans)
    await db.flush()
    
    # Обработка товаров (только для income/expense)
    if not is_transfer and trans_data.items:
        for item in trans_data.items:
            prod_result = await db.execute(select(Product).where(Product.id == item.product_id, Product.company_id == company_id))
            product = prod_result.scalar_one_or_none()
            if not product:
                raise HTTPException(status_code=404, detail=f"Product {item.product_id} not found")
            if trans_data.type.value == 'income':
                product.current_quantity -= Decimal(str(item.quantity))
            else:
                product.current_quantity += Decimal(str(item.quantity))
            trans_item = TransactionItem(
                transaction_id=new_trans.id,
                product_id=item.product_id,
                quantity=item.quantity,
                price_per_unit=item.price_per_unit
            )
            db.add(trans_item)
    
    # ========== ОБНОВЛЯЕМ БАЛАНС ТОЛЬКО ДЛЯ ОПЛАЧЕННЫХ ТРАНЗАКЦИЙ ==========
    if new_trans.is_paid:
        await recalc_account_balance(new_trans.account_id, db)
        if is_transfer and new_trans.transfer_to_account_id is not None:
            await recalc_account_balance(new_trans.transfer_to_account_id, db)
    
    await db.commit()
    await db.refresh(new_trans)
    await db.refresh(new_trans, attribute_names=['creator', 'updater'])
    
    items_result = await db.execute(
        select(TransactionItem).where(TransactionItem.transaction_id == new_trans.id)
        .options(selectinload(TransactionItem.product))
    )
    items = items_result.scalars().all()
    items_response = [
        TransactionItemResponse(
            product_id=it.product_id,
            product_name=it.product.name,
            quantity=it.quantity,
            price_per_unit=it.price_per_unit,
            total=it.quantity * (it.price_per_unit or 0)
        ) for it in items
    ]
    
    return TransactionResponse(
        id=new_trans.id,
        type=new_trans.type,
        amount=new_trans.amount,
        date=new_trans.date,
        account_id=new_trans.account_id,
        category_id=new_trans.category_id,
        description=new_trans.description,
        attachment_url=new_trans.attachment_url,
        created_by=new_trans.created_by,
        updated_by=new_trans.updated_by,
        is_deleted=new_trans.is_deleted,
        deleted_by=new_trans.deleted_by,
        deleted_at=new_trans.deleted_at,
        transfer_to_account_id=new_trans.transfer_to_account_id,
        creator_name=new_trans.creator.display_name if new_trans.creator else None,
        updater_name=new_trans.updater.display_name if new_trans.updater else None,
        number=new_trans.number,
        items=items_response,
        counterparty=new_trans.counterparty,
        showcase_item_id=new_trans.showcase_item_id
    )

@router.get("/", response_model=List[TransactionResponse])
async def get_transactions(
    company_id: int,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    type: Optional[TransactionType] = None,
    category_id: Optional[int] = None,
    account_id: Optional[int] = None,
    include_deleted: bool = False,
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
    
    query = select(Transaction).where(Transaction.company_id == company_id)
    if not include_deleted:
        query = query.where(Transaction.is_deleted == False)
    if start_date:
        if start_date.tzinfo:
            start_date = start_date.replace(tzinfo=None)
        query = query.where(Transaction.date >= start_date)
    if end_date:
        if end_date.tzinfo:
            end_date = end_date.replace(tzinfo=None)
        query = query.where(Transaction.date <= end_date)
    if type:
        query = query.where(Transaction.type == type.value)
    if category_id:
        query = query.where(Transaction.category_id == category_id)
    if account_id:
        query = query.where(Transaction.account_id == account_id)
    
    query = query.order_by(Transaction.date.desc())
    query = query.options(
        selectinload(Transaction.creator),
        selectinload(Transaction.updater),
        selectinload(Transaction.items).selectinload(TransactionItem.product)
    )
    result = await db.execute(query)
    transactions = result.scalars().all()
    
    response = []
    for t in transactions:
        items_response = [
            TransactionItemResponse(
                product_id=it.product_id,
                product_name=it.product.name,
                quantity=it.quantity,
                price_per_unit=it.price_per_unit,
                total=it.quantity * (it.price_per_unit or 0)
            ) for it in t.items
        ]
        response.append(TransactionResponse(
            id=t.id,
            type=t.type,
            amount=t.amount,
            date=t.date,
            account_id=t.account_id,
            category_id=t.category_id,
            description=t.description,
            attachment_url=t.attachment_url,
            created_by=t.created_by,
            updated_by=t.updated_by,
            is_deleted=t.is_deleted,
            deleted_by=t.deleted_by,
            deleted_at=t.deleted_at,
            transfer_to_account_id=t.transfer_to_account_id,
            creator_name=t.creator.display_name if t.creator else None,
            updater_name=t.updater.display_name if t.updater else None,
            number=t.number,
            items=items_response,
            counterparty=t.counterparty,
            showcase_item_id=t.showcase_item_id,
            is_paid=t.is_paid,
            paid_at=t.paid_at,
            payment_due_date=t.payment_due_date

        ))
    return response

@router.get("/{transaction_id}", response_model=TransactionResponse)
async def get_transaction(
    transaction_id: int,
    company_id: int,
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
    
    query = select(Transaction).where(Transaction.id == transaction_id, Transaction.company_id == company_id)
    query = query.options(
        selectinload(Transaction.creator),
        selectinload(Transaction.updater),
        selectinload(Transaction.items).selectinload(TransactionItem.product)
    )
    result = await db.execute(query)
    t = result.scalar_one_or_none()
    if not t:
        raise HTTPException(status_code=404, detail="Transaction not found")
    
    items_response = [
        TransactionItemResponse(
            product_id=it.product_id,
            product_name=it.product.name,
            quantity=it.quantity,
            price_per_unit=it.price_per_unit,
            total=it.quantity * (it.price_per_unit or 0)
        ) for it in t.items
    ]
    return TransactionResponse(
        id=t.id,
        type=t.type,
        amount=t.amount,
        date=t.date,
        account_id=t.account_id,
        category_id=t.category_id,
        description=t.description,
        attachment_url=t.attachment_url,
        created_by=t.created_by,
        updated_by=t.updated_by,
        is_deleted=t.is_deleted,
        deleted_by=t.deleted_by,
        deleted_at=t.deleted_at,
        transfer_to_account_id=t.transfer_to_account_id,
        creator_name=t.creator.display_name if t.creator else None,
        updater_name=t.updater.display_name if t.updater else None,
        number=t.number,
        items=items_response,
        counterparty=t.counterparty,
        showcase_item_id=t.showcase_item_id,
        is_paid=t.is_paid,
        paid_at=t.paid_at,
        payment_due_date=t.payment_due_date
    )

@router.patch("/{transaction_id}", response_model=TransactionResponse)
async def update_transaction(
    transaction_id: int,
    company_id: int,
    trans_data: TransactionCreate,
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
    
    result = await db.execute(select(Transaction).where(Transaction.id == transaction_id, Transaction.company_id == company_id))
    transaction = result.scalar_one_or_none()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    
    # ---- ИСПРАВЛЕНИЕ: сохраняем старый тип и старые товары до изменений ----
    old_account_id = transaction.account_id
    old_transfer_to = transaction.transfer_to_account_id
    old_type = transaction.type

    # Загружаем старые товары ДО изменения транзакции
    old_items_result = await db.execute(
        select(TransactionItem).where(TransactionItem.transaction_id == transaction_id)
        .options(selectinload(TransactionItem.product))
    )
    old_items = old_items_result.scalars().all()
    
    # 1. Откатываем влияние старых товаров, используя СТАРЫЙ тип
    for old_item in old_items:
        product = old_item.product
        if old_type == 'income':
            # раньше товар ушёл со склада → возвращаем на склад
            product.current_quantity += Decimal(str(old_item.quantity))
        elif old_type == 'expense':
            # раньше товар пришёл на склад → списываем
            product.current_quantity -= Decimal(str(old_item.quantity))
        # для transfer товаров нет, игнорируем
    # ----------------------------------------------------------------

    if trans_data.date.tzinfo is not None:
        trans_data.date = trans_data.date.replace(tzinfo=None)
    
    # НОРМАЛИЗАЦИЯ КОНТРАГЕНТА
    normalized_counterparty = await _normalize_counterparty(company_id, trans_data.counterparty, db)
    
    if normalized_counterparty:
        existing_cp = await db.execute(
            select(Counterparty).where(
                Counterparty.company_id == company_id,
                func.lower(Counterparty.name) == normalized_counterparty.lower()
            )
        )
        if not existing_cp.scalar_one_or_none():
            new_cp = Counterparty(
                company_id=company_id,
                name=normalized_counterparty,
                inn=None,
                phone=None,
                director=None
            )
            db.add(new_cp)
            await db.flush()
    
    # Обновляем основные поля
    transaction.account_id = trans_data.account_id
    transaction.type = trans_data.type.value
    transaction.amount = trans_data.amount
    transaction.date = trans_data.date
    transaction.category_id = trans_data.category_id
    transaction.description = trans_data.description
    transaction.updated_by = current_user.id
    transaction.counterparty = normalized_counterparty
    transaction.showcase_item_id = trans_data.showcase_item_id
    
    is_transfer = (trans_data.type.value == 'transfer')
    if is_transfer:
        transaction.transfer_to_account_id = trans_data.transfer_to_account_id
    else:
        transaction.transfer_to_account_id = None

    # Обработка вложения
    if trans_data.delete_attachment or trans_data.attachment_url is None:
        transaction.attachment_url = None
        transaction.attachment_uploaded_at = None
    else:
        transaction.attachment_url = trans_data.attachment_url
    
    await db.flush()
    
    # 2. Удаляем старые записи товаров (после отката)
    await db.execute(delete(TransactionItem).where(TransactionItem.transaction_id == transaction_id))
    
    # 3. Добавляем новые товары с НОВЫМ типом
    if not is_transfer and trans_data.items:
        for item in trans_data.items:
            prod_result = await db.execute(select(Product).where(Product.id == item.product_id, Product.company_id == company_id))
            product = prod_result.scalar_one_or_none()
            if not product:
                raise HTTPException(status_code=404, detail=f"Product {item.product_id} not found")
            if trans_data.type.value == 'income':
                product.current_quantity -= Decimal(str(item.quantity))
            else:  # expense
                product.current_quantity += Decimal(str(item.quantity))
            trans_item = TransactionItem(
                transaction_id=transaction_id,
                product_id=item.product_id,
                quantity=item.quantity,
                price_per_unit=item.price_per_unit
            )
            db.add(trans_item)
    
    # Пересчёт балансов счетов
    await recalc_account_balance(old_account_id, db)
    if old_transfer_to:
        await recalc_account_balance(old_transfer_to, db)
    await recalc_account_balance(transaction.account_id, db)
    if transaction.transfer_to_account_id:
        await recalc_account_balance(transaction.transfer_to_account_id, db)
    
    await db.commit()
    await db.refresh(transaction)
    await db.refresh(transaction, attribute_names=['creator', 'updater'])
    
    items_result = await db.execute(
        select(TransactionItem).where(TransactionItem.transaction_id == transaction_id)
        .options(selectinload(TransactionItem.product))
    )
    items = items_result.scalars().all()
    items_response = [
        TransactionItemResponse(
            product_id=it.product_id,
            product_name=it.product.name,
            quantity=it.quantity,
            price_per_unit=it.price_per_unit,
            total=it.quantity * (it.price_per_unit or 0)
        ) for it in items
    ]
    
    return TransactionResponse(
        id=transaction.id,
        type=transaction.type,
        amount=transaction.amount,
        date=transaction.date,
        account_id=transaction.account_id,
        category_id=transaction.category_id,
        description=transaction.description,
        attachment_url=transaction.attachment_url,
        created_by=transaction.created_by,
        updated_by=transaction.updated_by,
        is_deleted=transaction.is_deleted,
        deleted_by=transaction.deleted_by,
        deleted_at=transaction.deleted_at,
        transfer_to_account_id=transaction.transfer_to_account_id,
        creator_name=transaction.creator.display_name if transaction.creator else None,
        updater_name=transaction.updater.display_name if transaction.updater else None,
        number=transaction.number,
        items=items_response,
        counterparty=transaction.counterparty,
        showcase_item_id=transaction.showcase_item_id,
        is_paid=transaction.is_paid,          
        paid_at=transaction.paid_at,          
        payment_due_date=transaction.payment_due_date  
    )

@router.delete("/{transaction_id}")
async def delete_transaction(
    transaction_id: int,
    company_id: int,
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
    
    result = await db.execute(select(Transaction).where(Transaction.id == transaction_id, Transaction.company_id == company_id))
    transaction = result.scalar_one_or_none()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    
    # 👇 ДОБАВИТЬ ПРОВЕРКУ НА ПРОИЗВОДСТВЕННУЮ ТРАНЗАКЦИЮ 👇
    from app.models import ProductionStockTransaction, ManufacturedProduct, Account
    
    # Проверяем, является ли транзакция продажей готовой продукции
    stock_tx_result = await db.execute(
        select(ProductionStockTransaction).where(
            ProductionStockTransaction.transaction_id == transaction_id,
            ProductionStockTransaction.type == "SALE"
        )
    )
    stock_tx = stock_tx_result.scalar_one_or_none()
    
    if stock_tx:
        # Это производственная транзакция, возвращаем товар на склад
        product_result = await db.execute(
            select(ManufacturedProduct).where(ManufacturedProduct.id == stock_tx.product_id)
        )
        product = product_result.scalar_one_or_none()
        if product:
            # stock_tx.quantity отрицательное, так что вычитаем = прибавляем
            product.current_stock -= stock_tx.quantity
        
        # Удаляем запись из production_stock_transactions
        await db.delete(stock_tx)
    
    # 👇 ОСТАЛЬНОЙ КОД БЕЗ ИЗМЕНЕНИЙ 👇
    items_result = await db.execute(
        select(TransactionItem).where(TransactionItem.transaction_id == transaction_id)
        .options(selectinload(TransactionItem.product))
    )
    items = items_result.scalars().all()
    
    order_payment = await db.execute(
        select(OrderPayment).where(OrderPayment.transaction_id == transaction_id)
    )
    order_payment = order_payment.scalar_one_or_none()
    if order_payment:
        order_id = order_payment.order_id
    
    # Удаление записи журнала
    from app.models import JournalEntry
    journal_entry = await db.execute(
        select(JournalEntry).where(JournalEntry.transaction_id == transaction_id)
    )
    journal_entry = journal_entry.scalar_one_or_none()
    if journal_entry:
        await db.delete(journal_entry)
    
    if current_user.role == UserRole.FOUNDER:
        if order_payment:
            await db.delete(order_payment)
            await _recalc_paid_amount(order_id, db)
    
        for item in items:
            product = item.product
            if transaction.type == 'income':
                product.current_quantity += Decimal(str(item.quantity))
            else:
                product.current_quantity -= Decimal(str(item.quantity))
    
        await db.delete(transaction)
        await recalc_account_balance(transaction.account_id, db)
        if transaction.transfer_to_account_id:
            await recalc_account_balance(transaction.transfer_to_account_id, db)
        await db.commit()
        return {"detail": "Transaction permanently deleted"}
    
    else:
        if transaction.is_deleted:
            raise HTTPException(status_code=400, detail="Transaction already deleted")
        transaction.is_deleted = True
        transaction.deleted_by = current_user.id
        transaction.deleted_at = datetime.utcnow()
        await db.flush()
        await recalc_account_balance(transaction.account_id, db)
        if transaction.transfer_to_account_id:
            await recalc_account_balance(transaction.transfer_to_account_id, db)
        await db.commit()
        return {"detail": "Transaction soft-deleted"}

@router.post("/{transaction_id}/restore")
async def restore_transaction(
    transaction_id: int,
    company_id: int,
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
    
    result = await db.execute(select(Transaction).where(Transaction.id == transaction_id, Transaction.company_id == company_id))
    transaction = result.scalar_one_or_none()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    
    if not transaction.is_deleted:
        raise HTTPException(status_code=400, detail="Transaction is not deleted")
    
    # ---- ИСПРАВЛЕНИЕ: при восстановлении применяем влияние товаров заново ----
    items_result = await db.execute(
        select(TransactionItem).where(TransactionItem.transaction_id == transaction_id)
        .options(selectinload(TransactionItem.product))
    )
    items = items_result.scalars().all()
    for item in items:
        product = item.product
        if transaction.type == 'income':
            product.current_quantity -= Decimal(str(item.quantity))
        elif transaction.type == 'expense':
            product.current_quantity += Decimal(str(item.quantity))
        # для transfer товаров нет
    # -------------------------------------------------------------------------

    transaction.is_deleted = False
    transaction.deleted_by = None
    transaction.deleted_at = None
    
    await db.flush()
    await recalc_account_balance(transaction.account_id, db)
    if transaction.transfer_to_account_id:
        await recalc_account_balance(transaction.transfer_to_account_id, db)
    
    await db.commit()
    return {"detail": "Transaction restored"}

@router.post("/upload")
async def upload_general_transaction_file(
    company_id: int,
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")

    file.file.seek(0, 2)
    size = file.file.tell()
    if size > MAX_FILE_SIZE:
        raise HTTPException(status_code=400, detail=f"File too large (max {MAX_FILE_SIZE // (1024*1024)} MB)")
    await file.seek(0)

    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=400, detail="Only JPG, JPEG, PNG, PDF files are allowed")

    try:
        contents = await file.read()
        bucket = storage.bucket()
        blob_path = f"companies/{company_id}/transactions/{uuid.uuid4()}{ext}"
        blob = bucket.blob(blob_path)

        blob.upload_from_string(contents, content_type=file.content_type)
        blob.make_public()
        public_url = blob.public_url

        return {"url": public_url}

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ошибка загрузки в Firebase Storage: {str(e)}")

async def _sync_counterparty(company_id: int, name: str | None, db: AsyncSession, user_id: int) -> None:
    """Создаёт запись в таблице counterparties, если контрагент ещё не существует (без учёта регистра)."""
    if not name:
        return
    from sqlalchemy import func
    existing = await db.execute(
        select(Counterparty).where(
            Counterparty.company_id == company_id,
            func.lower(Counterparty.name) == name.lower()
        )
    )
    cp = existing.scalar_one_or_none()
    if not cp:
        new_cp = Counterparty(
            company_id=company_id,
            name=name,
            inn=None,
            phone=None,
            director=None,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )
        db.add(new_cp)
        await db.flush()

@router.get("/{transaction_id}/file")
async def get_transaction_file(
    transaction_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    import aiohttp
    from fastapi.responses import Response
    
    result = await db.execute(select(Transaction).where(Transaction.id == transaction_id))
    transaction = result.scalar_one_or_none()
    if not transaction or not transaction.attachment_url:
        raise HTTPException(status_code=404, detail="File not found")
    
    async with aiohttp.ClientSession() as session:
        async with session.get(transaction.attachment_url) as resp:
            content = await resp.read()
    
    return Response(content=content, media_type="application/octet-stream")   

@router.patch("/{transaction_id}/pay")
async def mark_transaction_paid(
    transaction_id: int,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Отметить транзакцию как оплаченную
    Применяется для всех типов транзакций: продажи с витрины, производства, журнала
    """
    # Проверка доступа к компании
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    # Находим транзакцию
    result = await db.execute(
        select(Transaction).where(
            Transaction.id == transaction_id,
            Transaction.company_id == company_id
        )
    )
    transaction = result.scalar_one_or_none()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    
    if transaction.is_paid:
        raise HTTPException(status_code=400, detail="Transaction already paid")
    
    # Отмечаем как оплаченную
    transaction.is_paid = True
    transaction.paid_at = datetime.utcnow()
    
    # Обновляем баланс счета (только если это не перевод)
    if transaction.type != 'transfer':
        account = await db.get(Account, transaction.account_id)
        if account:
            account.balance += transaction.amount
    
    await db.commit()
    await db.refresh(transaction)
    
    return {
        "message": "Transaction marked as paid",
        "transaction_id": transaction.id,
        "is_paid": transaction.is_paid,
        "paid_at": transaction.paid_at
    }


@router.patch("/{transaction_id}/unpay")
async def mark_transaction_unpaid(
    transaction_id: int,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Снять отметку об оплате (только для учредителя)
    """
    # Проверка доступа к компании
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    # Только учредитель может снимать отметку об оплате
    if current_user.role != UserRole.FOUNDER:
        raise HTTPException(status_code=403, detail="Only founder can unpay transactions")
    
    # Находим транзакцию
    result = await db.execute(
        select(Transaction).where(
            Transaction.id == transaction_id,
            Transaction.company_id == company_id
        )
    )
    transaction = result.scalar_one_or_none()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    
    if not transaction.is_paid:
        raise HTTPException(status_code=400, detail="Transaction is not paid")
    
    # Снимаем отметку об оплате
    transaction.is_paid = False
    transaction.paid_at = None
    
    # Возвращаем баланс счета
    if transaction.type != 'transfer':
        account = await db.get(Account, transaction.account_id)
        if account:
            account.balance -= transaction.amount
    
    await db.commit()
    await db.refresh(transaction)
    
    return {
        "message": "Transaction marked as unpaid",
        "transaction_id": transaction.id,
        "is_paid": transaction.is_paid,
        "paid_at": transaction.paid_at
    }     