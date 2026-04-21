from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime
from decimal import Decimal

from app.database import get_db
from app.models import User, Company, Product, StockEntry, StockWriteOff, CompanyMember, UserRole
from app.deps import get_current_user

router = APIRouter(prefix="/stock", tags=["stock"])

# ---------- Схемы ----------
class StockEntryCreate(BaseModel):
    product_id: int
    quantity: float
    price_per_unit: float
    description: Optional[str] = None

class StockEntryResponse(BaseModel):
    id: int
    product_id: int
    product_name: str
    quantity: float
    price_per_unit: float
    date: datetime
    description: Optional[str]
    created_by: int

    class Config:
        from_attributes = True

class StockWriteOffCreate(BaseModel):
    product_id: int
    quantity: float
    reason: str  # 'sale', 'spoilage', 'loss'
    description: Optional[str] = None

class StockWriteOffResponse(BaseModel):
    id: int
    product_id: int
    product_name: str
    quantity: float
    reason: str
    date: datetime
    description: Optional[str]
    created_by: int

    class Config:
        from_attributes = True

class ProductStockResponse(BaseModel):
    id: int
    name: str
    unit: str
    current_quantity: float
    price_per_unit: Optional[float]

    class Config:
        from_attributes = True

# ---------- Вспомогательные функции ----------
async def _check_company_access(company_id: int, current_user: User, db: AsyncSession) -> bool:
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
        if result.scalar_one_or_none():
            return True
    result = await db.execute(select(CompanyMember).where(CompanyMember.company_id == company_id, CompanyMember.user_id == current_user.id))
    return result.scalar_one_or_none() is not None

# ---------- Товары с остатками ----------
@router.get("/products", response_model=List[ProductStockResponse])
async def get_stock_products(
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(status_code=403, detail="Access denied")
    result = await db.execute(select(Product).where(Product.company_id == company_id).order_by(Product.name))
    products = result.scalars().all()
    return [ProductStockResponse.model_validate(p) for p in products]

# ---------- Приход товара ----------
@router.post("/entry", response_model=StockEntryResponse)
async def create_stock_entry(
    company_id: int,
    entry_data: StockEntryCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(status_code=403, detail="Access denied")
    
    # Проверяем товар
    result = await db.execute(select(Product).where(Product.id == entry_data.product_id, Product.company_id == company_id))
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    
    # Создаём запись прихода
    new_entry = StockEntry(
        company_id=company_id,
        product_id=entry_data.product_id,
        quantity=entry_data.quantity,
        price_per_unit=entry_data.price_per_unit,
        description=entry_data.description,
        created_by=current_user.id
    )
    db.add(new_entry)
    
    # Обновляем текущее количество товара
    product.current_quantity += Decimal(str(entry_data.quantity))
    
    await db.commit()
    await db.refresh(new_entry)
    
    return StockEntryResponse(
        id=new_entry.id,
        product_id=new_entry.product_id,
        product_name=product.name,
        quantity=new_entry.quantity,
        price_per_unit=new_entry.price_per_unit,
        date=new_entry.date,
        description=new_entry.description,
        created_by=new_entry.created_by
    )

# ---------- Списание товара ----------
@router.post("/write-off", response_model=StockWriteOffResponse)
async def create_stock_write_off(
    company_id: int,
    write_off_data: StockWriteOffCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(status_code=403, detail="Access denied")
    
    # Проверяем товар
    result = await db.execute(select(Product).where(Product.id == write_off_data.product_id, Product.company_id == company_id))
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    
    # Проверяем, что достаточно остатка
    if product.current_quantity < write_off_data.quantity:
        raise HTTPException(status_code=400, detail=f"Insufficient stock. Available: {product.current_quantity}")
    
    # Создаём запись списания
    new_write_off = StockWriteOff(
        company_id=company_id,
        product_id=write_off_data.product_id,
        quantity=write_off_data.quantity,
        reason=write_off_data.reason,
        description=write_off_data.description,
        created_by=current_user.id
    )
    db.add(new_write_off)
    
    # Обновляем текущее количество товара
    product.current_quantity -= Decimal(str(write_off_data.quantity))
    
    await db.commit()
    await db.refresh(new_write_off)
    
    return StockWriteOffResponse(
        id=new_write_off.id,
        product_id=new_write_off.product_id,
        product_name=product.name,
        quantity=new_write_off.quantity,
        reason=new_write_off.reason,
        date=new_write_off.date,
        description=new_write_off.description,
        created_by=new_write_off.created_by
    )

# ---------- История приходов ----------
@router.get("/entries", response_model=List[StockEntryResponse])
async def get_stock_entries(
    company_id: int,
    product_id: Optional[int] = None,
    limit: int = 100,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(status_code=403, detail="Access denied")
    
    query = select(StockEntry).where(StockEntry.company_id == company_id)
    if product_id:
        query = query.where(StockEntry.product_id == product_id)
    query = query.order_by(StockEntry.date.desc()).limit(limit)
    result = await db.execute(query)
    entries = result.scalars().all()
    
    response = []
    for e in entries:
        prod_result = await db.execute(select(Product).where(Product.id == e.product_id))
        product = prod_result.scalar_one()
        response.append(StockEntryResponse(
            id=e.id,
            product_id=e.product_id,
            product_name=product.name,
            quantity=e.quantity,
            price_per_unit=e.price_per_unit,
            date=e.date,
            description=e.description,
            created_by=e.created_by
        ))
    return response

# ---------- История списаний ----------
@router.get("/write-offs", response_model=List[StockWriteOffResponse])
async def get_stock_write_offs(
    company_id: int,
    product_id: Optional[int] = None,
    limit: int = 100,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(status_code=403, detail="Access denied")
    
    query = select(StockWriteOff).where(StockWriteOff.company_id == company_id)
    if product_id:
        query = query.where(StockWriteOff.product_id == product_id)
    query = query.order_by(StockWriteOff.date.desc()).limit(limit)
    result = await db.execute(query)
    write_offs = result.scalars().all()
    
    response = []
    for w in write_offs:
        prod_result = await db.execute(select(Product).where(Product.id == w.product_id))
        product = prod_result.scalar_one()
        response.append(StockWriteOffResponse(
            id=w.id,
            product_id=w.product_id,
            product_name=product.name,
            quantity=w.quantity,
            reason=w.reason,
            date=w.date,
            description=w.description,
            created_by=w.created_by
        ))
    return response