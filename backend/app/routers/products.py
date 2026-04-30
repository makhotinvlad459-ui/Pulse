from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from typing import List, Optional
from enum import Enum
from datetime import datetime
from pydantic import BaseModel  # <-- добавить эту строку

from app.database import get_db
from app.models import User, Company, Product, CompanyMember, UserRole, ProductType
from app.deps import get_current_user

router = APIRouter(prefix="/products", tags=["products"])

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
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(status_code=403, detail="Access denied")
    query = select(Product).where(Product.company_id == company_id)
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
        raise HTTPException(status_code=403, detail="Access denied")
    result = await db.execute(select(Product).where(Product.id == product_id, Product.company_id == company_id))
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    await db.delete(product)
    await db.commit()
    return {"detail": "Product deleted"}