from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from fastapi import Query
from typing import List

from app.database import get_db
from app.models import User, Company, Category, Transaction, TransactionType, CompanyMember, UserRole
from app.schemas import CategoryCreate, CategoryResponse
from app.deps import get_current_user

router = APIRouter(prefix="/categories", tags=["categories"])

@router.post("/", response_model=CategoryResponse)
async def create_category(
    category_data: CategoryCreate,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Проверяем доступ к компании
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(
            select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id)
        )
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    # Преобразуем тип в строку, если это enum
    type_str = category_data.type.value if hasattr(category_data.type, 'value') else category_data.type
    
    new_category = Category(
    company_id=company_id,
    name=category_data.name,
    type=category_data.type.value,  
    is_system=False,
    created_by=current_user.id,
    icon=category_data.icon
)
    db.add(new_category)
    await db.commit()
    await db.refresh(new_category)
    return new_category

@router.delete("/{category_id}")
async def delete_category(
    category_id: int,
    company_id: int = Query(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Проверяем доступ
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(
            select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id)
        )
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    # Находим категорию
    result = await db.execute(select(Category).where(Category.id == category_id, Category.company_id == company_id))
    category = result.scalar_one_or_none()
    if not category:
        raise HTTPException(status_code=404, detail="Category not found")
    if category.is_system:
        raise HTTPException(status_code=400, detail="Cannot delete system category")
    
    # Находим или создаём системную категорию "Без категории"
    result = await db.execute(select(Category).where(Category.company_id == company_id, Category.is_system == True))
    default_category = result.scalar_one_or_none()
    if not default_category:
        default_category = Category(
            company_id=company_id,
            name="Без категории",
            type='income',  # строка, а не enum
            is_system=True,
            created_by=current_user.id,
            icon='📁'
        )
        db.add(default_category)
        await db.flush()
    
    # Переназначаем транзакции
    await db.execute(update(Transaction).where(Transaction.category_id == category_id).values(category_id=default_category.id))
    
    # Удаляем категорию
    await db.delete(category)
    await db.commit()
    return {"detail": "Category deleted and transactions reassigned to 'Без категории'"}

@router.get("/", response_model=List[CategoryResponse])
async def get_categories(
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Проверяем доступ
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(
            select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id)
        )
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    result = await db.execute(select(Category).where(Category.company_id == company_id))
    categories = result.scalars().all()
    return categories