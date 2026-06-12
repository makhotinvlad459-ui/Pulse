from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, and_
from typing import List, Optional
from decimal import Decimal

from app.database import get_db
from app.models import Company, ManufacturedProduct, ProductionJournalEntry, ProductionStockTransaction, ProductionTransactionType, Transaction, TransactionType, Account
from app.schemas.production import (
    ManufacturedProduct as ManufacturedProductSchema,
    ManufacturedProductCreate,
    ManufacturedProductUpdate,
    ProductionJournalEntry as ProductionJournalEntrySchema,
    ProductionJournalEntryCreate,
    ProductionJournalEntryUpdate,
    ProductionStockTransaction as ProductionStockTransactionSchema,
    ProductionProductWithRecipe,
    RecipeItem,
)
from app.auth import get_current_user
from app.models import User
import json

router = APIRouter(prefix="/production", tags=["production"])


# ---------- Управление производимыми товарами ----------
@router.get("/products", response_model=List[ManufacturedProductSchema])
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


@router.post("/products", response_model=ManufacturedProductSchema)
async def create_manufactured_product(
    product: ManufacturedProductCreate,
    company_id: int = Query(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Создать производимый товар"""
    # Проверяем права доступа к компании
    # ... (проверка членства)
    
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


@router.patch("/products/{product_id}", response_model=ManufacturedProductSchema)
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
        # Получаем названия продуктов
        from app.models import Product
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


# ---------- Производство (создание записи и списание со склада сырья) ----------
@router.post("/produce")
async def produce_product(
    product_id: int,
    quantity: float,
    production_date: str,
    shift: str = "day",
    worker_name: str = None,
    notes: str = None,
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
    
    # Получаем товар и его рецепт
    result = await db.execute(
        select(ManufacturedProduct).where(ManufacturedProduct.id == product_id)
    )
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    
    # Создаем запись в журнале
    journal_entry = ProductionJournalEntry(
        company_id=company_id,
        product_id=product_id,
        planned_quantity=quantity,
        actual_quantity=quantity,
        production_date=production_date,
        shift=shift,
        worker_name=worker_name,
        notes=notes,
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
                mat_quantity = float(item.get('quantity', 0)) * quantity
                
                # Получаем сырьевой товар
                mat_result = await db.execute(
                    select(Product).where(Product.id == mat_product_id)
                )
                mat_product = mat_result.scalar_one_or_none()
                if mat_product:
                    # Списываем со склада
                    write_off = StockWriteOff(
                        company_id=company_id,
                        product_id=mat_product_id,
                        quantity=mat_quantity,
                        reason=f"Производство: {product.name} x{quantity}",
                        date=production_date,
                        created_by=current_user.id,
                    )
                    db.add(write_off)
                    
                    # Обновляем остаток
                    mat_product.current_quantity -= mat_quantity
        except json.JSONDecodeError:
            pass
    
    # Создаем транзакцию прихода на склад ГП
    stock_transaction = ProductionStockTransaction(
        company_id=company_id,
        product_id=product_id,
        type=ProductionTransactionType.PRODUCTION,
        quantity=quantity,
        journal_entry_id=journal_entry.id,
        created_by=current_user.id,
    )
    db.add(stock_transaction)
    
    # Обновляем остаток готовой продукции
    product.current_stock += quantity
    
    await db.commit()
    
    return {"message": f"Produced {quantity} of {product.name}", "journal_entry_id": journal_entry.id}


# ---------- Продажа готовой продукции ----------
@router.post("/sell")
async def sell_product(
    product_id: int,
    quantity: float,
    amount: float,
    account_id: int,
    date: str,
    counterparty: str = None,
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
    """
    # Получаем товар
    result = await db.execute(
        select(ManufacturedProduct).where(ManufacturedProduct.id == product_id)
    )
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    
    if product.current_stock < quantity:
        raise HTTPException(status_code=400, detail="Not enough stock")
    
    # Создаем финансовую транзакцию
    transaction = Transaction(
        company_id=company_id,
        account_id=account_id,
        type="income",
        amount=amount,
        date=date,
        description=f"Продажа готовой продукции: {product.name} x{quantity}",
        counterparty=counterparty,
        created_by=current_user.id,
    )
    db.add(transaction)
    await db.flush()
    
    # Создаем транзакцию расхода со склада ГП
    stock_transaction = ProductionStockTransaction(
        company_id=company_id,
        product_id=product_id,
        type=ProductionTransactionType.SALE,
        quantity=-quantity,  # отрицательное количество для расхода
        price_per_unit=amount / quantity if quantity > 0 else 0,
        transaction_id=transaction.id,
        created_by=current_user.id,
    )
    db.add(stock_transaction)
    
    # Обновляем остаток
    product.current_stock -= quantity
    
    await db.commit()
    
    return {
        "message": f"Sold {quantity} of {product.name}",
        "transaction_id": transaction.id
    }


# ---------- Производственный журнал ----------
@router.get("/journal", response_model=List[ProductionJournalEntrySchema])
async def get_production_journal(
    company_id: int = Query(...),
    start_date: Optional[str] = Query(None),
    end_date: Optional[str] = Query(None),
    product_id: Optional[int] = Query(None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Получить записи производственного журнала"""
    query = select(ProductionJournalEntry).where(ProductionJournalEntry.company_id == company_id)
    
    if start_date:
        query = query.where(ProductionJournalEntry.production_date >= start_date)
    if end_date:
        query = query.where(ProductionJournalEntry.production_date <= end_date)
    if product_id:
        query = query.where(ProductionJournalEntry.product_id == product_id)
    
    query = query.order_by(ProductionJournalEntry.production_date.desc())
    
    result = await db.execute(query)
    entries = result.scalars().all()
    return entries


@router.get("/journal/{entry_id}", response_model=ProductionJournalEntrySchema)
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


@router.put("/journal/{entry_id}", response_model=ProductionJournalEntrySchema)
async def update_production_journal_entry(
    entry_id: int,
    entry_data: ProductionJournalEntryUpdate,
    company_id: int = Query(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Обновить запись (только если не завершена)"""
    result = await db.execute(
        select(ProductionJournalEntry).where(
            ProductionJournalEntry.id == entry_id,
            ProductionJournalEntry.company_id == company_id
        )
    )
    entry = result.scalar_one_or_none()
    if not entry:
        raise HTTPException(status_code=404, detail="Entry not found")
    
    # Нельзя редактировать завершенные записи? Или можно, но с пересчетом остатков?
    # Пока просто обновляем
    
    update_data = entry_data.model_dump(exclude_unset=True)
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
            product.current_stock -= entry.actual_quantity  # откатываем приход
        
        # Удаляем stock_transaction
        await db.delete(stock_tx)
    
    # Удаляем запись
    await db.delete(entry)
    await db.commit()
    
    return {"message": "Entry deleted"}


# ---------- Статистика и остатки ----------
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


@router.get("/stock/transactions", response_model=List[ProductionStockTransactionSchema])
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