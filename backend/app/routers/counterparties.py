from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List
from pydantic import BaseModel
from datetime import datetime

from app.database import get_db
from app.models import User, Company, Counterparty, CompanyMember, UserRole
from app.deps import get_current_user

router = APIRouter(prefix="/counterparties", tags=["counterparties"], redirect_slashes=False)

class CounterpartyCreate(BaseModel):
    name: str
    inn: str | None = None
    phone: str | None = None
    director: str | None = None

class CounterpartyUpdate(BaseModel):
    name: str | None = None
    inn: str | None = None
    phone: str | None = None
    director: str | None = None

class CounterpartyResponse(BaseModel):
    id: int
    company_id: int
    name: str
    inn: str | None
    phone: str | None
    director: str | None
    created_at: datetime
    updated_at: datetime

async def _check_company_access(company_id: int, current_user: User, db: AsyncSession) -> bool:
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
        if result.scalar_one_or_none():
            return True
    result = await db.execute(select(CompanyMember).where(CompanyMember.company_id == company_id, CompanyMember.user_id == current_user.id))
    return result.scalar_one_or_none() is not None

@router.get("/", response_model=List[CounterpartyResponse])
async def list_counterparties(
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    result = await db.execute(select(Counterparty).where(Counterparty.company_id == company_id).order_by(Counterparty.name))
    return result.scalars().all()

@router.post("/", response_model=CounterpartyResponse)
async def create_counterparty(
    company_id: int,
    data: CounterpartyCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    # Проверяем уникальность имени (без учёта регистра)
    from sqlalchemy import func
    existing = await db.execute(
        select(Counterparty).where(
            Counterparty.company_id == company_id,
            func.lower(Counterparty.name) == data.name.lower()
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(400, "Counterparty with similar name already exists")
    cp = Counterparty(company_id=company_id, **data.dict())
    db.add(cp)
    await db.commit()
    await db.refresh(cp)
    return cp

@router.put("/{counterparty_id}", response_model=CounterpartyResponse)
async def update_counterparty(
    counterparty_id: int,
    company_id: int,
    data: CounterpartyUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    cp = await db.get(Counterparty, counterparty_id)
    if not cp or cp.company_id != company_id:
        raise HTTPException(404, "Counterparty not found")
    for key, value in data.dict(exclude_unset=True).items():
        setattr(cp, key, value)
    cp.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(cp)
    return cp

@router.delete("/{counterparty_id}")
async def delete_counterparty(
    counterparty_id: int,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    cp = await db.get(Counterparty, counterparty_id)
    if not cp or cp.company_id != company_id:
        raise HTTPException(404, "Counterparty not found")
    await db.delete(cp)
    await db.commit()
    return {"detail": "Deleted"}