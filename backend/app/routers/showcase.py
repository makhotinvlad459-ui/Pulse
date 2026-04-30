from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List, Optional
from datetime import datetime

from app.database import get_db
from app.models import User, Company, ShowcaseItem, CompanyMember, UserRole, Permission, CompanyMemberPermission
from app.schemas import ShowcaseItemCreate, ShowcaseItemUpdate, ShowcaseItemResponse
from app.deps import get_current_user

router = APIRouter(prefix="/showcase", tags=["showcase"])

async def _check_company_access(company_id: int, current_user: User, db: AsyncSession) -> bool:
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
        if result.scalar_one_or_none():
            return True
    result = await db.execute(select(CompanyMember).where(CompanyMember.company_id == company_id, CompanyMember.user_id == current_user.id))
    return result.scalar_one_or_none() is not None

async def _can_edit(company_id: int, current_user: User, db: AsyncSession) -> bool:
    # Учредитель может редактировать
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
        if result.scalar_one_or_none():
            return True
    # Проверяем, есть ли у пользователя право edit_showcase
    member = await db.execute(
        select(CompanyMember).where(CompanyMember.company_id == company_id, CompanyMember.user_id == current_user.id)
    )
    member = member.scalar_one_or_none()
    if not member:
        return False
    perm = await db.execute(
        select(CompanyMemberPermission).join(Permission).where(
            CompanyMemberPermission.member_id == member.id,
            Permission.name == 'edit_showcase'
        )
    )
    return perm.scalar_one_or_none() is not None

@router.get("/", response_model=List[ShowcaseItemResponse])
async def get_showcase_items(
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(status_code=403, detail="Access denied")
    result = await db.execute(select(ShowcaseItem).where(ShowcaseItem.company_id == company_id).order_by(ShowcaseItem.sort_order))
    return result.scalars().all()

@router.post("/", response_model=ShowcaseItemResponse)
async def create_showcase_item(
    company_id: int,
    item_data: ShowcaseItemCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _can_edit(company_id, current_user, db):
        raise HTTPException(status_code=403, detail="You don't have edit_showcase permission")
    new_item = ShowcaseItem(
        company_id=company_id,
        name=item_data.name,
        price=item_data.price,
        sort_order=item_data.sort_order or 0,
        image_url=item_data.image_url,
        recipe=item_data.recipe,
        category_id=item_data.category_id
    )
    db.add(new_item)
    await db.commit()
    await db.refresh(new_item)
    return new_item

@router.patch("/{item_id}", response_model=ShowcaseItemResponse)
async def update_showcase_item(
    item_id: int,
    company_id: int,
    item_data: ShowcaseItemUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _can_edit(company_id, current_user, db):
        raise HTTPException(status_code=403, detail="You don't have edit_showcase permission")
    result = await db.execute(select(ShowcaseItem).where(ShowcaseItem.id == item_id, ShowcaseItem.company_id == company_id))
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    if item_data.name is not None:
        item.name = item_data.name
    if item_data.price is not None:
        item.price = item_data.price
    if item_data.sort_order is not None:
        item.sort_order = item_data.sort_order
    if item_data.image_url is not None:
        item.image_url = item_data.image_url
    if item_data.recipe is not None:
        item.recipe = item_data.recipe
    if item_data.category_id is not None:
        item.category_id = item_data.category_id
    item.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(item)
    return item

@router.delete("/{item_id}")
async def delete_showcase_item(
    item_id: int,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _can_edit(company_id, current_user, db):
        raise HTTPException(status_code=403, detail="You don't have edit_showcase permission")
    result = await db.execute(select(ShowcaseItem).where(ShowcaseItem.id == item_id, ShowcaseItem.company_id == company_id))
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    await db.delete(item)
    await db.commit()
    return {"detail": "Item deleted"}

@router.post("/reorder")
async def reorder_showcase_items(
    company_id: int,
    ids: List[int],
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _can_edit(company_id, current_user, db):
        raise HTTPException(status_code=403, detail="You don't have edit_showcase permission")
    for idx, item_id in enumerate(ids):
        await db.execute(update(ShowcaseItem).where(ShowcaseItem.id == item_id, ShowcaseItem.company_id == company_id).values(sort_order=idx))
    await db.commit()
    return {"detail": "Order updated"}