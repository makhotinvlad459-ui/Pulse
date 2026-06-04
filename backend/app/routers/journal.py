from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List, Optional
from datetime import datetime
import json

from app.database import get_db
from app.models import User, Company, CompanyMember, JournalEntry, JournalEntryStatus, ShowcaseItem, Account, Permission, CompanyMemberPermission
from app.schemas import JournalEntryCreate, JournalEntryUpdate, JournalEntryResponse, TransactionCreate, TransactionType, JournalEntryItemCreate
from app.deps import get_current_user
from app.routers.transactions import create_transaction

router = APIRouter(prefix="/journal", tags=["journal"])


def _to_naive(dt: datetime | None) -> datetime | None:
    if dt is None:
        return None
    if dt.tzinfo is not None:
        return dt.replace(tzinfo=None)
    return dt


async def _check_company_access(company_id: int, user: User, db: AsyncSession) -> bool:
    if user.role == "founder":
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == user.id))
        if result.scalar_one_or_none():
            return True
    result = await db.execute(select(CompanyMember).where(CompanyMember.company_id == company_id, CompanyMember.user_id == user.id))
    return result.scalar_one_or_none() is not None


async def _has_permission(company_id: int, user: User, permission_name: str, db: AsyncSession) -> bool:
    if user.role == "founder":
        return True
    member = await db.execute(
        select(CompanyMember).where(CompanyMember.company_id == company_id, CompanyMember.user_id == user.id)
    )
    member = member.scalar_one_or_none()
    if not member:
        return False
    perm = await db.execute(
        select(CompanyMemberPermission).join(Permission).where(
            CompanyMemberPermission.member_id == member.id,
            Permission.name == permission_name
        )
    )
    return perm.scalar_one_or_none() is not None


@router.get("/", response_model=List[JournalEntryResponse])
async def get_journal_entries(
    company_id: int,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(status_code=403, detail="Access denied")
    if not await _has_permission(company_id, current_user, "view_journal", db):
        raise HTTPException(status_code=403, detail="No permission to view journal")

    start_date = _to_naive(start_date)
    end_date = _to_naive(end_date)

    query = select(JournalEntry).where(JournalEntry.company_id == company_id)
    if start_date:
        query = query.where(JournalEntry.datetime_start >= start_date)
    if end_date:
        query = query.where(JournalEntry.datetime_start <= end_date)
    query = query.order_by(JournalEntry.datetime_start)
    result = await db.execute(query)
    entries = result.scalars().all()
    return entries


@router.post("/", response_model=JournalEntryResponse)
async def create_journal_entry(
    company_id: int,
    entry_data: JournalEntryCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(status_code=403, detail="Access denied")
    if not await _has_permission(company_id, current_user, "create_journal", db):
        raise HTTPException(status_code=403, detail="No permission to create journal entries")

    start = _to_naive(entry_data.datetime_start)
    end = _to_naive(entry_data.datetime_end)
    if end <= start:
        raise HTTPException(status_code=400, detail="End time must be after start time")

    items_data = [item.dict() for item in entry_data.items] if entry_data.items else None

    new_entry = JournalEntry(
        company_id=company_id,
        datetime_start=start,
        datetime_end=end,
        description=entry_data.description,
        counterparty=entry_data.counterparty,
        showcase_item_id=entry_data.showcase_item_id,
        quantity=entry_data.quantity,
        total_amount=entry_data.total_amount,
        created_by=current_user.id,
        status=JournalEntryStatus.PLANNED,
        items=items_data
    )
    db.add(new_entry)
    await db.commit()
    await db.refresh(new_entry)
    return new_entry


@router.patch("/{entry_id}", response_model=JournalEntryResponse)
async def update_journal_entry(
    entry_id: int,
    company_id: int,
    entry_data: JournalEntryUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(status_code=403, detail="Access denied")
    if not await _has_permission(company_id, current_user, "edit_journal", db):
        raise HTTPException(status_code=403, detail="No permission to edit journal entries")

    result = await db.execute(select(JournalEntry).where(JournalEntry.id == entry_id, JournalEntry.company_id == company_id))
    entry = result.scalar_one_or_none()
    if not entry:
        raise HTTPException(status_code=404, detail="Entry not found")
    if entry.status != JournalEntryStatus.PLANNED:
        raise HTTPException(status_code=400, detail="Only planned entries can be edited")

    update_data = entry_data.dict(exclude_unset=True)
    if 'datetime_start' in update_data:
        update_data['datetime_start'] = _to_naive(update_data['datetime_start'])
    if 'datetime_end' in update_data:
        update_data['datetime_end'] = _to_naive(update_data['datetime_end'])
    if 'items' in update_data and update_data['items'] is not None:
        update_data['items'] = [item.dict() for item in update_data['items']]

    for key, value in update_data.items():
        setattr(entry, key, value)
    entry.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(entry)
    return entry


@router.delete("/{entry_id}")
async def delete_journal_entry(
    entry_id: int,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(status_code=403, detail="Access denied")
    if not await _has_permission(company_id, current_user, "delete_journal", db):
        raise HTTPException(status_code=403, detail="No permission to delete journal entries")

    result = await db.execute(select(JournalEntry).where(JournalEntry.id == entry_id, JournalEntry.company_id == company_id))
    entry = result.scalar_one_or_none()
    if not entry:
        raise HTTPException(status_code=404, detail="Entry not found")
    if entry.status != JournalEntryStatus.PLANNED:
        # Если запись завершена и есть транзакция, удаляем транзакцию (она удалит и запись)
        if entry.transaction_id:
            from app.routers.transactions import delete_transaction
            await delete_transaction(entry.transaction_id, company_id, db, current_user)
        else:
            await db.delete(entry)
        await db.commit()
        return {"detail": "Entry deleted"}
    else:
        await db.delete(entry)
        await db.commit()
        return {"detail": "Entry deleted"}


@router.post("/{entry_id}/complete")
async def complete_journal_entry(
    entry_id: int,
    company_id: int,
    account_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(status_code=403, detail="Access denied")
    if not await _has_permission(company_id, current_user, "complete_journal", db):
        raise HTTPException(status_code=403, detail="No permission to complete journal entries")

    result = await db.execute(select(JournalEntry).where(JournalEntry.id == entry_id, JournalEntry.company_id == company_id))
    entry = result.scalar_one_or_none()
    if not entry:
        raise HTTPException(status_code=404, detail="Entry not found")
    if entry.status != JournalEntryStatus.PLANNED:
        raise HTTPException(status_code=400, detail="Entry already completed or cancelled")

    acc = await db.execute(select(Account).where(Account.id == account_id, Account.company_id == company_id))
    if not acc.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Account not found")

    total_amount = 0.0
    transaction_items = []

    if entry.items:
        for item in entry.items:
            showcase_item = await db.get(ShowcaseItem, item['showcase_item_id'])
            if not showcase_item:
                raise HTTPException(status_code=404, detail=f"Showcase item {item['showcase_item_id']} not found")
            price = item['price_at_time']
            qty = item['quantity']
            subtotal = price * qty
            total_amount += subtotal

            if showcase_item.recipe:
                recipe = json.loads(showcase_item.recipe)
                for recipe_item in recipe:
                    transaction_items.append({
                        'product_id': recipe_item['product_id'],
                        'quantity': recipe_item['quantity'] * qty,
                        'price_per_unit': price
                    })
    else:
        if entry.showcase_item_id:
            item = await db.get(ShowcaseItem, entry.showcase_item_id)
            if not item:
                raise HTTPException(status_code=404, detail="Showcase item not found")
            total_amount = item.price * entry.quantity
            if item.recipe:
                recipe = json.loads(item.recipe)
                for recipe_item in recipe:
                    transaction_items.append({
                        'product_id': recipe_item['product_id'],
                        'quantity': recipe_item['quantity'] * entry.quantity,
                        'price_per_unit': item.price
                    })
        else:
            total_amount = entry.total_amount

    description = f"Journal: {entry.description or 'Entry'}"

    from app.schemas import TransactionItemCreate
    items_create = [
        TransactionItemCreate(
            product_id=ti['product_id'],
            quantity=ti['quantity'],
            price_per_unit=ti['price_per_unit']
        ) for ti in transaction_items
    ]

    trans_data = TransactionCreate(
        type=TransactionType.INCOME,
        amount=total_amount,
        date=datetime.utcnow(),
        account_id=account_id,
        description=description,
        counterparty=entry.counterparty,
        showcase_item_id=None,
        quantity=1,
        items=items_create
    )

    created_trans = await create_transaction(
        trans_data=trans_data,
        company_id=company_id,
        db=db,
        current_user=current_user
    )

    entry.transaction_id = created_trans.id
    entry.status = JournalEntryStatus.COMPLETED
    await db.commit()

    return {"detail": "Entry completed and transaction created", "transaction_id": created_trans.id}