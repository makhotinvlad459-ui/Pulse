from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, delete, and_
from typing import List, Optional
from decimal import Decimal
import json
from datetime import datetime
from sqlalchemy.orm import selectinload
from app.models import Counterparty
from app.routers.transactions import delete_transaction as base_delete_transaction
from app.routers.transactions import get_next_transaction_number

from app.database import get_db
from app.models import Company, ManufacturedProduct, ProductionJournalEntry, ProductionStockTransaction, ProductionTransactionType, Transaction, TransactionType, Account, Product, StockWriteOff, User,Counterparty
from app.schemas import (
    ManufacturedProductResponse,
    ManufacturedProductCreate,
    ManufacturedProductUpdate,
    ProductionJournalEntryResponse,
    ProductionJournalEntryCreate,
    ProductionJournalEntryUpdate,
    ProductionStockTransactionResponse,
    RecipeItem,
    ProductionProductWithRecipe,
    ProductionSellRequest,
    ProductionProduceRequest,
)
from app.auth import get_current_user

router = APIRouter(prefix="/production", tags=["production"])


# ========== ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ ДЛЯ КОНВЕРТАЦИИ ДАТ ==========
def _to_naive(dt: datetime | None) -> datetime | None:
    if dt is None:
        return None
    if dt.tzinfo is not None:
        return dt.replace(tzinfo=None)
    return dt


# ========== УПРАВЛЕНИЕ ПРОИЗВОДИМЫМИ ТОВАРАМИ ==========
@router.get("/products", response_model=List[ManufacturedProductResponse])
async def get_manufactured_products(
    company_id: int = Query(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Получить список производимых товаров"""
    result = await db.execute(
        select(ManufacturedProduct)
        .where(ManufacturedProduct.company_id == company_id)
        .where(ManufacturedProduct.is_deleted == False)
        .order_by(ManufacturedProduct.sort_order)
    )
    products = result.scalars().all()
    return products


@router.post("/products", response_model=ManufacturedProductResponse)
async def create_manufactured_product(
    product: ManufacturedProductCreate,
    company_id: int = Query(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Создать производимый товар"""
    new_product = ManufacturedProduct(
        company_id=company_id,
        name=product.name,
        unit=product.unit,
        price=product.price,
        recipe=product.recipe,
        sort_order=product.sort_order,
    )
    db.add(new_product)
    await db.commit()
    await db.refresh(new_product)
    return new_product


@router.patch("/products/{product_id}", response_model=ManufacturedProductResponse)
async def update_manufactured_product(
    product_id: int,
    product: ManufacturedProductUpdate,
    company_id: int = Query(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Обновить производимый товар"""
    result = await db.execute(
        select(ManufacturedProduct).where(
            ManufacturedProduct.id == product_id,
            ManufacturedProduct.company_id == company_id
        )
    )
    existing = result.scalar_one_or_none()
    if not existing:
        raise HTTPException(status_code=404, detail="Product not found")
    
    update_data = product.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(existing, key, value)
    
    await db.commit()
    await db.refresh(existing)
    return existing


@router.delete("/products/{product_id}")
async def delete_manufactured_product(
    product_id: int,
    company_id: int = Query(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Мягкое удаление производимого товара"""
    result = await db.execute(
        select(ManufacturedProduct).where(
            ManufacturedProduct.id == product_id,
            ManufacturedProduct.company_id == company_id
        )
    )
    existing = result.scalar_one_or_none()
    if not existing:
        raise HTTPException(status_code=404, detail="Product not found")
    
    existing.is_deleted = True
    await db.commit()
    return {"message": "Product deleted"}


@router.post("/products/reorder")
async def reorder_products(
    product_ids: List[int],
    company_id: int = Query(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Изменить порядок товаров"""
    for idx, pid in enumerate(product_ids):
        await db.execute(
            update(ManufacturedProduct)
            .where(ManufacturedProduct.id == pid, ManufacturedProduct.company_id == company_id)
            .values(sort_order=idx)
        )
    await db.commit()
    return {"message": "Order updated"}


@router.get("/products/{product_id}/recipe", response_model=List[RecipeItem])
async def get_product_recipe(
    product_id: int,
    company_id: int = Query(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Получить рецепт товара с названиями продуктов"""
    result = await db.execute(
        select(ManufacturedProduct).where(ManufacturedProduct.id == product_id)
    )
    product = result.scalar_one_or_none()
    if not product or not product.recipe:
        return []
    
    try:
        recipe_data = json.loads(product.recipe)
        result_items = []
        for item in recipe_data:
            prod_result = await db.execute(
                select(Product).where(Product.id == item.get('product_id'))
            )
            prod = prod_result.scalar_one_or_none()
            result_items.append(RecipeItem(
                product_id=item.get('product_id'),
                product_name=prod.name if prod else "Неизвестный товар",
                quantity=float(item.get('quantity', 0))
            ))
        return result_items
    except:
        return []


# ========== ПРОИЗВОДСТВО ==========
@router.post("/produce")
async def produce_product(
    data: ProductionProduceRequest,
    company_id: int = Query(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Произвести продукцию:
    1. Создать запись в производственном журнале
    2. Списать материалы со склада (есть рецепт)
    3. Увеличить остаток готовой продукции
    """
    from app.models import Product, StockWriteOff
    
    # Конвертируем дату в naive
    production_date = _to_naive(data.production_date)
    
    # Получаем товар и его рецепт
    result = await db.execute(
        select(ManufacturedProduct).where(ManufacturedProduct.id == data.product_id)
    )
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    
    # Создаем запись в журнале
    journal_entry = ProductionJournalEntry(
        company_id=company_id,
        product_id=data.product_id,
        planned_quantity=data.quantity,
        actual_quantity=data.quantity,
        production_date=production_date,
        shift=data.shift,
        worker_name=data.worker_name,
        notes=data.notes,
        status="completed",
        created_by=current_user.id,
    )
    db.add(journal_entry)
    await db.flush()
    
    # Если есть рецепт - списываем материалы
    if product.recipe:
        try:
            recipe = json.loads(product.recipe)
            for item in recipe:
                mat_product_id = item.get('product_id')
                mat_quantity = Decimal(str(float(item.get('quantity', 0)) * data.quantity))
                
                mat_result = await db.execute(
                    select(Product).where(Product.id == mat_product_id)
                )
                mat_product = mat_result.scalar_one_or_none()
                if mat_product:
                    write_off = StockWriteOff(
                        company_id=company_id,
                        product_id=mat_product_id,
                        quantity=mat_quantity,
                        reason=f"Производство: {product.name} x{data.quantity}",
                        date=production_date,
                        created_by=current_user.id,
                    )
                    db.add(write_off)
                    mat_product.current_quantity -= mat_quantity
        except json.JSONDecodeError:
            pass
    
    # Создаем транзакцию прихода на склад ГП
    quantity_decimal = Decimal(str(data.quantity))
    stock_transaction = ProductionStockTransaction(
        company_id=company_id,
        product_id=data.product_id,
        type=ProductionTransactionType.PRODUCTION,
        quantity=quantity_decimal,
        journal_entry_id=journal_entry.id,
        created_by=current_user.id,
    )
    db.add(stock_transaction)
    
    # Обновляем остаток готовой продукции
    product.current_stock += quantity_decimal
    
    await db.commit()
    
    return {"message": f"Produced {data.quantity} of {product.name}", "journal_entry_id": journal_entry.id}


# ========== ПРОДАЖА ГОТОВОЙ ПРОДУКЦИИ ==========
@router.post("/sell")
async def sell_product(
    data: ProductionSellRequest,
    company_id: int = Query(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Продажа готовой продукции:
    1. Проверить наличие на складе
    2. Уменьшить остаток готовой продукции
    3. Создать финансовую транзакцию (доход)
    4. Создать запись в stock_transactions
    5. Добавить контрагента в справочник (если указан и не существует)
    """
    # Получаем товар
    result = await db.execute(
        select(ManufacturedProduct).where(ManufacturedProduct.id == data.product_id)
    )
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    
    # Конвертируем дату в naive
    date_naive = _to_naive(data.date)
    
    quantity_decimal = Decimal(str(data.quantity))
    amount_decimal = Decimal(str(data.amount))
    
    if product.current_stock < quantity_decimal:
        raise HTTPException(status_code=400, detail="Not enough stock")
    
    # Добавляем контрагента в справочник
    if data.counterparty:
        existing_cp = await db.execute(
            select(Counterparty).where(
                Counterparty.company_id == company_id,
                Counterparty.name == data.counterparty
            )
        )
        if not existing_cp.scalar_one_or_none():
            new_counterparty = Counterparty(
                company_id=company_id,
                name=data.counterparty,
                created_at=datetime.utcnow(),
                updated_at=datetime.utcnow()
            )
            db.add(new_counterparty)
    
    # Генерация номера операции (используем общую функцию)
    new_number = await get_next_transaction_number(company_id, db)
    
    # Создаем финансовую транзакцию
    transaction = Transaction(
        company_id=company_id,
        account_id=data.account_id,
        type="income",
        amount=amount_decimal,
        date=date_naive,
        description=f"Sale of finished product: {product.name} x{data.quantity}",
        counterparty=data.counterparty,
        created_by=current_user.id,
        is_paid=data.is_paid,
        number=new_number,  # 👈 ИСПОЛЬЗУЕМ СГЕНЕРИРОВАННЫЙ НОМЕР
    )
    db.add(transaction)
    await db.flush()
    
    # Создаем транзакцию расхода со склада ГП
    stock_transaction = ProductionStockTransaction(
        company_id=company_id,
        product_id=data.product_id,
        type=ProductionTransactionType.SALE,
        quantity=-quantity_decimal,
        price_per_unit=amount_decimal / quantity_decimal if quantity_decimal > 0 else 0,
        transaction_id=transaction.id,
        created_by=current_user.id,
    )
    db.add(stock_transaction)
    
    # Обновляем остаток
    product.current_stock -= quantity_decimal
    
    await db.commit()
    
    return {
        "message": f"Sold {data.quantity} of {product.name}",
        "transaction_id": transaction.id
    }

# ========== ПРОИЗВОДСТВЕННЫЙ ЖУРНАЛ ==========
from sqlalchemy.orm import selectinload

@router.get("/journal", response_model=List[ProductionJournalEntryResponse])
async def get_production_journal(
    company_id: int = Query(...),
    start_date: Optional[datetime] = Query(None),
    end_date: Optional[datetime] = Query(None),
    product_id: Optional[int] = Query(None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = select(ProductionJournalEntry).where(ProductionJournalEntry.company_id == company_id).options(selectinload(ProductionJournalEntry.creator))
    
    start_naive = _to_naive(start_date)
    end_naive = _to_naive(end_date)
    
    if start_naive:
        query = query.where(ProductionJournalEntry.production_date >= start_naive)
    if end_naive:
        query = query.where(ProductionJournalEntry.production_date <= end_naive)
    if product_id:
        query = query.where(ProductionJournalEntry.product_id == product_id)
    
    query = query.order_by(ProductionJournalEntry.production_date.desc())
    
    result = await db.execute(query)
    entries = result.scalars().all()
    
    # Добавляем имя создателя
    for entry in entries:
        entry.creator_name = entry.creator.display_name if entry.creator else None
    
    return entries

@router.get("/journal/{entry_id}", response_model=ProductionJournalEntryResponse)
async def get_production_journal_entry(
    entry_id: int,
    company_id: int = Query(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(ProductionJournalEntry).where(
            ProductionJournalEntry.id == entry_id,
            ProductionJournalEntry.company_id == company_id
        )
    )
    entry = result.scalar_one_or_none()
    if not entry:
        raise HTTPException(status_code=404, detail="Entry not found")
    return entry


@router.put("/journal/{entry_id}", response_model=ProductionJournalEntryResponse)
async def update_production_journal_entry(
    entry_id: int,
    entry_data: ProductionJournalEntryUpdate,
    company_id: int = Query(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Обновить запись"""
    result = await db.execute(
        select(ProductionJournalEntry).where(
            ProductionJournalEntry.id == entry_id,
            ProductionJournalEntry.company_id == company_id
        )
    )
    entry = result.scalar_one_or_none()
    if not entry:
        raise HTTPException(status_code=404, detail="Entry not found")
    
    update_data = entry_data.model_dump(exclude_unset=True)
    
    # Конвертируем дату если есть
    if 'production_date' in update_data and update_data['production_date']:
        update_data['production_date'] = _to_naive(update_data['production_date'])
    
    for key, value in update_data.items():
        setattr(entry, key, value)
    
    await db.commit()
    await db.refresh(entry)
    return entry


@router.delete("/journal/{entry_id}")
async def delete_production_journal_entry(
    entry_id: int,
    company_id: int = Query(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Удалить запись и откатить изменения остатков"""
    result = await db.execute(
        select(ProductionJournalEntry).where(
            ProductionJournalEntry.id == entry_id,
            ProductionJournalEntry.company_id == company_id
        )
    )
    entry = result.scalar_one_or_none()
    if not entry:
        raise HTTPException(status_code=404, detail="Entry not found")
    
    # Получаем связанную stock_transaction
    stock_result = await db.execute(
        select(ProductionStockTransaction).where(
            ProductionStockTransaction.journal_entry_id == entry_id
        )
    )
    stock_tx = stock_result.scalar_one_or_none()
    
    if stock_tx and stock_tx.type == ProductionTransactionType.PRODUCTION:
        # Возвращаем остаток готовой продукции
        product_result = await db.execute(
            select(ManufacturedProduct).where(ManufacturedProduct.id == entry.product_id)
        )
        product = product_result.scalar_one_or_none()
        if product:
            product.current_stock -= entry.actual_quantity
        
        await db.delete(stock_tx)
    
    await db.delete(entry)
    await db.commit()
    
    return {"message": "Entry deleted"}


# ========== СТАТИСТИКА И ОСТАТКИ ==========
@router.get("/stock")
async def get_production_stock(
    company_id: int = Query(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Получить все товары с текущими остатками"""
    result = await db.execute(
        select(ManufacturedProduct)
        .where(ManufacturedProduct.company_id == company_id)
        .where(ManufacturedProduct.is_deleted == False)
    )
    products = result.scalars().all()
    
    return [
        {
            "id": p.id,
            "name": p.name,
            "unit": p.unit,
            "current_stock": float(p.current_stock),
            "price": float(p.price),
        }
        for p in products
    ]


@router.get("/stock/transactions", response_model=List[ProductionStockTransactionResponse])
async def get_stock_transactions(
    company_id: int = Query(...),
    product_id: Optional[int] = Query(None),
    start_date: Optional[str] = Query(None),
    end_date: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Получить историю движения склада ГП"""
    query = select(ProductionStockTransaction).where(ProductionStockTransaction.company_id == company_id)
    
    if product_id:
        query = query.where(ProductionStockTransaction.product_id == product_id)
    if start_date:
        query = query.where(ProductionStockTransaction.created_at >= start_date)
    if end_date:
        query = query.where(ProductionStockTransaction.created_at <= end_date)
    
    query = query.order_by(ProductionStockTransaction.created_at.desc())
    
    result = await db.execute(query)
    transactions = result.scalars().all()
    return transactions

@router.delete("/transaction/{transaction_id}")
async def delete_production_transaction(
    transaction_id: int,
    company_id: int = Query(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Удаление транзакции продажи готовой продукции:
    1. Найти связанную запись в production_stock_transactions
    2. Вернуть товар на склад ГП
    3. Обновить баланс счета
    4. Удалить production_stock_transactions
    5. Удалить транзакцию
    """
    # Находим транзакцию
    trans_result = await db.execute(
        select(Transaction).where(
            Transaction.id == transaction_id,
            Transaction.company_id == company_id,
        )
    )
    transaction = trans_result.scalar_one_or_none()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    
    # Находим связанную запись в production_stock_transactions
    stock_result = await db.execute(
        select(ProductionStockTransaction).where(
            ProductionStockTransaction.transaction_id == transaction_id
        )
    )
    stock_tx = stock_result.scalar_one_or_none()
    
    if stock_tx and stock_tx.type == ProductionTransactionType.SALE:
        # Возвращаем товар на склад ГП (quantity отрицательное, так что вычитаем = прибавляем)
        product_result = await db.execute(
            select(ManufacturedProduct).where(ManufacturedProduct.id == stock_tx.product_id)
        )
        product = product_result.scalar_one_or_none()
        if product:
            product.current_stock -= stock_tx.quantity  # было -1, вычитаем -1 = +1
        
        # Удаляем запись production_stock_transactions
        await db.delete(stock_tx)
    
    # Обновляем баланс счета (уменьшаем на сумму транзакции)
    account = await db.get(Account, transaction.account_id)
    if account:
        account.balance -= transaction.amount
    
    # Удаляем транзакцию
    await db.delete(transaction)
    await db.commit()
    
    return {"message": "Transaction deleted, stock returned"}

@router.get("/sales-report")
async def get_production_sales_report(
    company_id: int = Query(...),
    start_date: Optional[datetime] = Query(None),
    end_date: Optional[datetime] = Query(None),
    only_unpaid: bool = Query(False),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Отчет по продажам готовой продукции
    Возвращает список продаж с информацией о продукте, сумме, счете, контрагенте и статусе оплаты
    """
    from sqlalchemy import and_, select, func
    
    # Конвертируем даты в naive
    start_naive = _to_naive(start_date)
    end_naive = _to_naive(end_date)
    
    # Запрос: связываем ProductionStockTransaction (SALE) с Transaction и ManufacturedProduct
    query = (
        select(
            Transaction.id.label("transaction_id"),
            Transaction.date,
            Transaction.amount,
            Transaction.is_paid,
            Transaction.paid_at,
            Transaction.counterparty,
            Transaction.description,
            Account.name.label("account_name"),
            ManufacturedProduct.name.label("product_name"),
            ManufacturedProduct.unit,
            ProductionStockTransaction.quantity,
            ProductionStockTransaction.price_per_unit,
        )
        .join(
            ProductionStockTransaction,
            ProductionStockTransaction.transaction_id == Transaction.id,
        )
        .join(
            ManufacturedProduct,
            ManufacturedProduct.id == ProductionStockTransaction.product_id,
        )
        .join(
            Account,
            Account.id == Transaction.account_id,
        )
        .where(
            ProductionStockTransaction.type == ProductionTransactionType.SALE,
            ProductionStockTransaction.company_id == company_id,
            Transaction.company_id == company_id,
            Transaction.is_deleted == False,
        )
    )
    
    # Фильтр по дате (по дате транзакции, а не создания)
    if start_naive:
        query = query.where(Transaction.date >= start_naive)
    if end_naive:
        query = query.where(Transaction.date <= end_naive)
    
    # Фильтр по оплате
    if only_unpaid:
        query = query.where(Transaction.is_paid == False)
    
    # Сортировка по дате (сначала новые)
    query = query.order_by(Transaction.date.desc())
    
    result = await db.execute(query)
    rows = result.all()
    
    # Формируем ответ
    sales = []
    for row in rows:
        # quantity в ProductionStockTransaction хранится отрицательной для продаж
        quantity = abs(row.quantity) if row.quantity else 0
        amount = float(row.amount) if row.amount else 0
        
        sales.append({
            "transaction_id": row.transaction_id,
            "date": row.date.isoformat() if row.date else None,
            "product_name": row.product_name,
            "unit": row.unit or "шт",
            "quantity": float(quantity),
            "price_per_unit": float(row.price_per_unit) if row.price_per_unit else (amount / quantity if quantity > 0 else 0),
            "amount": amount,
            "account_name": row.account_name,
            "counterparty": row.counterparty,
            "is_paid": row.is_paid,
            "paid_at": row.paid_at.isoformat() if row.paid_at else None,
            "description": row.description,
        })
    
    return sales

@router.get("/sell-through-report")
async def get_sell_through_report(
    company_id: int = Query(...),
    start_date: Optional[datetime] = Query(None),
    end_date: Optional[datetime] = Query(None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Отчет по продаваемости товаров
    Показывает ВСЕ товары, у которых есть продажи или производство за период
    """
    start_naive = _to_naive(start_date)
    end_naive = _to_naive(end_date)
    
    # Получаем ID товаров, которые продавались за период
    sold_query = (
        select(ManufacturedProduct.id, ManufacturedProduct.name, ManufacturedProduct.unit, ManufacturedProduct.current_stock)
        .join(ProductionStockTransaction, ProductionStockTransaction.product_id == ManufacturedProduct.id)
        .where(
            ProductionStockTransaction.company_id == company_id,
            ProductionStockTransaction.type == ProductionTransactionType.SALE,
            ManufacturedProduct.is_deleted == False,
        )
    )
    if start_naive:
        sold_query = sold_query.where(ProductionStockTransaction.created_at >= start_naive)
    if end_naive:
        sold_query = sold_query.where(ProductionStockTransaction.created_at <= end_naive)
    
    sold_result = await db.execute(sold_query)
    sold_products = {row.id: {'name': row.name, 'unit': row.unit or 'шт', 'stock': float(row.current_stock)} 
                     for row in sold_result.all()}
    
    # Получаем ID товаров, которые производились за период
    produced_query = (
        select(ManufacturedProduct.id, ManufacturedProduct.name, ManufacturedProduct.unit, ManufacturedProduct.current_stock)
        .join(ProductionJournalEntry, ProductionJournalEntry.product_id == ManufacturedProduct.id)
        .where(
            ProductionJournalEntry.company_id == company_id,
            ManufacturedProduct.is_deleted == False,
        )
    )
    if start_naive:
        produced_query = produced_query.where(ProductionJournalEntry.production_date >= start_naive)
    if end_naive:
        produced_query = produced_query.where(ProductionJournalEntry.production_date <= end_naive)
    
    produced_result = await db.execute(produced_query)
    produced_products = {row.id: {'name': row.name, 'unit': row.unit or 'шт', 'stock': float(row.current_stock)} 
                         for row in produced_result.all()}
    
    # Объединяем уникальные ID из обоих источников
    all_product_ids = set(sold_products.keys()) | set(produced_products.keys())
    
    report = []
    for product_id in all_product_ids:
        product_info = sold_products.get(product_id) or produced_products.get(product_id)
        if not product_info:
            continue
        
        # Считаем произведенное количество
        produced_query = select(func.sum(ProductionJournalEntry.actual_quantity)).where(
            ProductionJournalEntry.product_id == product_id,
            ProductionJournalEntry.company_id == company_id,
        )
        if start_naive:
            produced_query = produced_query.where(ProductionJournalEntry.production_date >= start_naive)
        if end_naive:
            produced_query = produced_query.where(ProductionJournalEntry.production_date <= end_naive)
        produced_result = await db.execute(produced_query)
        produced_quantity = float(produced_result.scalar() or 0)
        
        # Считаем проданное количество
        sold_query = (
            select(func.sum(func.abs(ProductionStockTransaction.quantity)))
            .where(
                ProductionStockTransaction.product_id == product_id,
                ProductionStockTransaction.company_id == company_id,
                ProductionStockTransaction.type == ProductionTransactionType.SALE,
            )
        )
        if start_naive or end_naive:
            sold_query = sold_query.join(Transaction, ProductionStockTransaction.transaction_id == Transaction.id)
            if start_naive:
                sold_query = sold_query.where(Transaction.date >= start_naive)
            if end_naive:
                sold_query = sold_query.where(Transaction.date <= end_naive)
        sold_result = await db.execute(sold_query)
        sold_quantity = float(sold_result.scalar() or 0)
        
        # Процент продаж (ограничиваем 100)
        if produced_quantity > 0:
            sell_through_percent = min((sold_quantity / produced_quantity * 100), 100)
        else:
            sell_through_percent = 0
        
        report.append({
            "product_id": product_id,
            "product_name": product_info['name'],
            "unit": product_info['unit'],
            "produced_quantity": round(produced_quantity, 3),
            "sold_quantity": round(sold_quantity, 3),
            "current_stock": round(product_info['stock'], 3),
            "sell_through_percent": round(sell_through_percent, 1),
        })
    
    # Сортируем по убыванию процента
    report.sort(key=lambda x: x["sell_through_percent"], reverse=True)
    
    return report

@router.patch("/sales/{transaction_id}/mark-paid")
async def mark_sale_as_paid(
    transaction_id: int,
    company_id: int = Query(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Отметить продажу готовой продукции как оплаченную
    """
    # Проверяем, что транзакция существует и относится к компании
    result = await db.execute(
        select(Transaction).where(
            Transaction.id == transaction_id,
            Transaction.company_id == company_id,
            Transaction.is_deleted == False,
        )
    )
    transaction = result.scalar_one_or_none()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    
    if transaction.is_paid:
        raise HTTPException(status_code=400, detail="Transaction already paid")
    
    # Проверяем, что это продажа готовой продукции
    stock_result = await db.execute(
        select(ProductionStockTransaction).where(
            ProductionStockTransaction.transaction_id == transaction_id,
            ProductionStockTransaction.type == ProductionTransactionType.SALE,
        )
    )
    stock_tx = stock_result.scalar_one_or_none()
    if not stock_tx:
        raise HTTPException(status_code=400, detail="This transaction is not a production sale")
    
    # Отмечаем как оплаченную
    transaction.is_paid = True
    transaction.paid_at = datetime.utcnow()
    
    # Обновляем баланс счета
    account = await db.get(Account, transaction.account_id)
    if account:
        account.balance += transaction.amount
    
    await db.commit()
    
    return {
        "message": "Sale marked as paid",
        "transaction_id": transaction.id,
        "is_paid": transaction.is_paid,
        "paid_at": transaction.paid_at.isoformat() if transaction.paid_at else None,
    }