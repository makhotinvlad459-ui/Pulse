from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, func
from typing import List, Optional
from enum import Enum
from datetime import datetime
from pydantic import BaseModel
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models import User, Company, Product, CompanyMember, UserRole, ProductType, OrderItem, TransactionItem, Counterparty, StockWriteOff
from app.deps import get_current_user
from app.routers.orders import _has_permission

router = APIRouter(prefix="/products", tags=["products"], redirect_slashes=False)


# Enum для типа продукта
class ProductTypeEnum(str, Enum):
    PRODUCT = "product"
    MATERIAL = "material"


# Схемы
class ProductCreate(BaseModel):
    name: str
    unit: str
    type: ProductTypeEnum = ProductTypeEnum.PRODUCT
    label: Optional[str] = None
    size: Optional[str] = None
    barcode: Optional[str] = None
    supplier: Optional[str] = None


class ProductUpdate(BaseModel):
    name: Optional[str] = None
    unit: Optional[str] = None
    type: Optional[ProductTypeEnum] = None
    label: Optional[str] = None
    size: Optional[str] = None
    barcode: Optional[str] = None
    supplier: Optional[str] = None


class ProductResponse(BaseModel):
    id: int
    company_id: int
    name: str
    unit: str
    current_quantity: float
    created_at: datetime
    type: ProductTypeEnum
    label: Optional[str] = None
    size: Optional[str] = None
    barcode: Optional[str] = None
    supplier: Optional[str] = None

    class Config:
        from_attributes = True


# Вспомогательная функция проверки доступа
async def _check_company_access(company_id: int, current_user: User, db: AsyncSession) -> bool:
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
        if result.scalar_one_or_none():
            return True
    result = await db.execute(select(CompanyMember).where(CompanyMember.company_id == company_id, CompanyMember.user_id == current_user.id))
    return result.scalar_one_or_none() is not None


@router.get("/", response_model=List[ProductResponse])
async def get_products(
    company_id: int,
    type: Optional[ProductTypeEnum] = None,
    include_deleted: bool = False,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    query = select(Product).where(Product.company_id == company_id)
    if not include_deleted:
        query = query.where(Product.is_deleted == False)
    if type:
        query = query.where(Product.type == type.value)
    query = query.order_by(Product.name)
    result = await db.execute(query)
    products = result.scalars().all()
    return [ProductResponse.model_validate(p) for p in products]


@router.post("/", response_model=ProductResponse)
async def create_product(
    company_id: int,
    product_data: ProductCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(status_code=403, detail="Access denied")
    new_product = Product(
        company_id=company_id,
        name=product_data.name,
        unit=product_data.unit,
        current_quantity=0.0,
        type=product_data.type.value,
        label=product_data.label,
        size=product_data.size,
        barcode=product_data.barcode,
        supplier=product_data.supplier,
    )
    db.add(new_product)

    # ---- ДОБАВЛЯЕМ ПОСТАВЩИКА В СПРАВОЧНИК КОНТРАГЕНТОВ, ЕСЛИ УКАЗАН ----
    if product_data.supplier:
        existing_cp = await db.execute(
            select(Counterparty).where(
                Counterparty.company_id == company_id,
                func.lower(Counterparty.name) == product_data.supplier.lower()
            )
        )
        if not existing_cp.scalar_one_or_none():
            new_cp = Counterparty(
                company_id=company_id,
                name=product_data.supplier,
                inn=None,
                phone=None,
                director=None,
                created_at=datetime.utcnow(),
                updated_at=datetime.utcnow()
            )
            db.add(new_cp)

    await db.commit()
    await db.refresh(new_product)
    return ProductResponse.model_validate(new_product)


# ========== ЭНДПОИНТ ДЛЯ СПИСАНИЙ СО СКЛАДА (НОВЫЙ) ==========
@router.get("/stock-writeoffs")
async def get_stock_writeoffs(
    company_id: int = Query(...),
    start_date: Optional[datetime] = Query(None),
    end_date: Optional[datetime] = Query(None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")

    query = select(StockWriteOff).where(StockWriteOff.company_id == company_id)
    if start_date:
        query = query.where(StockWriteOff.date >= start_date)
    if end_date:
        query = query.where(StockWriteOff.date <= end_date)
    query = query.order_by(StockWriteOff.date.desc())
    query = query.options(selectinload(StockWriteOff.product))

    result = await db.execute(query)
    writeoffs = result.scalars().all()

    return [
        {
            "id": w.id,
            "product_id": w.product_id,
            "product_name": w.product.name if w.product else None,
            "quantity": float(w.quantity),
            "reason": w.reason,
            "date": w.date.isoformat(),
        }
        for w in writeoffs
    ]


@router.get("/{product_id}", response_model=ProductResponse)
async def get_product(
    product_id: int,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(status_code=403, detail="Access denied")
    result = await db.execute(select(Product).where(Product.id == product_id, Product.company_id == company_id))
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return ProductResponse.model_validate(product)


@router.patch("/{product_id}", response_model=ProductResponse)
async def update_product(
    product_id: int,
    company_id: int,
    product_data: ProductUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(status_code=403, detail="Access denied")
    result = await db.execute(select(Product).where(Product.id == product_id, Product.company_id == company_id))
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    if product_data.name is not None:
        product.name = product_data.name
    if product_data.unit is not None:
        product.unit = product_data.unit
    if product_data.type is not None:
        product.type = product_data.type.value
    if product_data.label is not None:
        product.label = product_data.label
    if product_data.size is not None:
        product.size = product_data.size
    if product_data.barcode is not None:
        product.barcode = product_data.barcode
    if product_data.supplier is not None:
        product.supplier = product_data.supplier
    await db.commit()
    await db.refresh(product)
    return ProductResponse.model_validate(product)


@router.delete("/{product_id}")
async def delete_product(
    product_id: int,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")

    product = await db.get(Product, product_id)
    if not product or product.company_id != company_id:
        raise HTTPException(404, "Product not found")

    perm_name = "edit_product" if product.type == ProductType.PRODUCT else "edit_material"
    if not await _has_permission(company_id, current_user, db, perm_name):
        raise HTTPException(403, f"No permission to delete {product.type}")

    # Проверяем, используется ли товар в заказах или транзакциях
    used_in_orders = await db.execute(
        select(OrderItem).where(OrderItem.product_id == product_id).limit(1)
    )
    used_in_transactions = await db.execute(
        select(TransactionItem).where(TransactionItem.product_id == product_id).limit(1)
    )
    if used_in_orders.first() or used_in_transactions.first():
        # Мягкое удаление – помечаем как удалённый
        product.is_deleted = True
        await db.commit()
        return {"detail": "Product marked as deleted (used in orders/transactions)"}
    else:
        await db.delete(product)
        await db.commit()
        return {"detail": "Product permanently deleted"}