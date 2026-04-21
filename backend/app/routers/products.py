from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, func
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime

from app.database import get_db
from app.models import User, Company, Product, CompanyMember, UserRole
from app.deps import get_current_user

router = APIRouter(prefix="/products", tags=["products"])

# ---------- Схемы ----------
class ProductCreate(BaseModel):
    name: str
    unit: str  # 'kg', 'liter', 'piece', 'g', 'ml'
    price_per_unit: Optional[float] = None

class ProductUpdate(BaseModel):
    name: Optional[str] = None
    unit: Optional[str] = None
    price_per_unit: Optional[float] = None

class ProductResponse(BaseModel):
    id: int
    company_id: int
    name: str
    unit: str
    current_quantity: float
    price_per_unit: Optional[float]
    created_at: datetime

    class Config:
        from_attributes = True

# ---------- Вспомогательные функции ----------
async def _check_company_access(company_id: int, current_user: User, db: AsyncSession) -> bool:
    """Проверяет, имеет ли пользователь доступ к компании"""
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
        if result.scalar_one_or_none():
            return True
    result = await db.execute(select(CompanyMember).where(CompanyMember.company_id == company_id, CompanyMember.user_id == current_user.id))
    return result.scalar_one_or_none() is not None

# ---------- CRUD ----------
@router.get("/", response_model=List[ProductResponse])
async def get_products(
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(status_code=403, detail="Access denied")
    result = await db.execute(select(Product).where(Product.company_id == company_id).order_by(Product.name))
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
        price_per_unit=product_data.price_per_unit,
        current_quantity=0.0
    )
    db.add(new_product)
    await db.commit()
    await db.refresh(new_product)
    return ProductResponse.model_validate(new_product)

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
    if product_data.price_per_unit is not None:
        product.price_per_unit = product_data.price_per_unit
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
        raise HTTPException(status_code=403, detail="Access denied")
    result = await db.execute(select(Product).where(Product.id == product_id, Product.company_id == company_id))
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    await db.delete(product)
    await db.commit()
    return {"detail": "Product deleted"}