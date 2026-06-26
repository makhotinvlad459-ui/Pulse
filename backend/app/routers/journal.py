from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from typing import List, Optional
from datetime import datetime
import json
import os
import uuid
from sqlalchemy.orm.attributes import flag_modified
from app.database import get_db
from app.models import User,  Company, CompanyMember, JournalEntry, JournalEntryStatus, ShowcaseItem, Account, Permission, CompanyMemberPermission, JournalAttachment, UserRole
from app.schemas import JournalEntryCreate, JournalEntryUpdate, JournalEntryResponse, TransactionCreate, TransactionType, JournalEntryItemCreate
from app.deps import get_current_user
from app.routers.transactions import create_transaction
from firebase_admin import storage
import aiohttp
from fastapi.responses import Response

router = APIRouter(prefix="/journal", tags=["journal"])

MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB
ALLOWED_EXTENSIONS = {
    '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp',
    '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.txt', '.rtf'
}


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


# ✅ ЕДИНСТВЕННЫЙ ПРАВИЛЬНЫЙ МЕТОД GET
@router.get("/", response_model=List[JournalEntryResponse])
async def get_journal_entries(
    company_id: int,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    assigned_to_id: Optional[int] = None,
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
    if assigned_to_id is not None:
        query = query.where(JournalEntry.assigned_to_id == assigned_to_id)

    # ✅ ЗАГРУЖАЕМ attachments и creator
    query = query.order_by(JournalEntry.datetime_start).options(
        selectinload(JournalEntry.attachments),
        selectinload(JournalEntry.creator),
    )
    result = await db.execute(query)
    entries = result.scalars().all()

    # Подгружаем assigned_to вручную через run_sync
    def _load_users(sync_db):
        user_ids = [e.assigned_to_id for e in entries if e.assigned_to_id is not None]
        if not user_ids:
            return {}
        result = sync_db.execute(
            select(User.id, User.full_name, User.role).where(User.id.in_(user_ids))
        )
        return {row.id: {"full_name": row.full_name, "role": row.role} for row in result.all()}

    user_map = await db.run_sync(_load_users) if entries else {}

    response_entries = []
    for entry in entries:
        user_data = user_map.get(entry.assigned_to_id)
        assigned_name = None
        if user_data:
            if user_data["role"] == UserRole.FOUNDER:
                assigned_name = "Основатель"
            else:
                assigned_name = user_data["full_name"]

        response_entries.append(JournalEntryResponse(
            id=entry.id,
            company_id=entry.company_id,
            datetime_start=entry.datetime_start,
            datetime_end=entry.datetime_end,
            description=entry.description,
            counterparty=entry.counterparty,
            status=entry.status,
            transaction_id=entry.transaction_id,
            showcase_item_id=entry.showcase_item_id,
            quantity=entry.quantity,
            total_amount=entry.total_amount,
            created_by=entry.created_by,
            created_at=entry.created_at,
            updated_at=entry.updated_at,
            creator_name=entry.creator.display_name if entry.creator else None,
            items=entry.items,
            attachments=entry.attachments,
            assigned_to_id=entry.assigned_to_id,
            assigned_to_name=assigned_name,
        ))

    return response_entries


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
        items=items_data,
        assigned_to_id=entry_data.assigned_to_id,
    )
    db.add(new_entry)
    await db.commit()
    await db.refresh(new_entry)

    result = await db.execute(
        select(JournalEntry)
        .where(JournalEntry.id == new_entry.id)
        .options(selectinload(JournalEntry.attachments))
    )
    new_entry = result.scalar_one()

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
        items_dicts = []
        for item in entry_data.items:
            item_dict = item.dict()
            if not item_dict.get('name') and item_dict.get('showcase_item_id'):
                showcase = await db.get(ShowcaseItem, item_dict['showcase_item_id'])
                if showcase:
                    item_dict['name'] = showcase.name
            items_dicts.append(item_dict)
        update_data['items'] = items_dicts

    for key, value in update_data.items():
        setattr(entry, key, value)
    
    if 'items' in update_data:
        flag_modified(entry, 'items')
    
    entry.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(entry)

    result = await db.execute(
        select(JournalEntry)
        .where(JournalEntry.id == entry.id)
        .options(selectinload(JournalEntry.attachments))
    )
    entry = result.scalar_one()

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
        items=items_create,
        is_paid=False,
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


# ========== ВЛОЖЕНИЯ ЖУРНАЛА ==========

@router.post("/{entry_id}/attachments")
async def upload_journal_attachment(
    entry_id: int,
    company_id: int,
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    if not await _has_permission(company_id, current_user, "edit_journal", db):
        raise HTTPException(403, "No permission to edit journal")

    result = await db.execute(
        select(JournalEntry).where(
            JournalEntry.id == entry_id,
            JournalEntry.company_id == company_id
        )
    )
    entry = result.scalar_one_or_none()
    if not entry:
        raise HTTPException(404, "Journal entry not found")

    file.file.seek(0, 2)
    size = file.file.tell()
    if size > MAX_FILE_SIZE:
        raise HTTPException(400, detail=f"File too large (max {MAX_FILE_SIZE // (1024*1024)} MB)")
    await file.seek(0)

    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(400, detail="File type not allowed. Allowed: images, PDF, Word, Excel, TXT")

    try:
        contents = await file.read()
        bucket = storage.bucket()
        blob_path = f"companies/{company_id}/journal/{entry_id}/{uuid.uuid4()}{ext}"
        blob = bucket.blob(blob_path)

        blob.upload_from_string(contents, content_type=file.content_type)
        blob.make_public()
        public_url = blob.public_url

        attachment = JournalAttachment(
            journal_entry_id=entry_id,
            file_url=public_url,
            uploaded_by=current_user.id,
            file_name=file.filename
        )
        db.add(attachment)
        await db.commit()
        await db.refresh(attachment)

        return {
            "id": attachment.id,
            "file_url": attachment.file_url,
            "uploaded_by": attachment.uploaded_by,
            "uploaded_at": attachment.uploaded_at.isoformat() if attachment.uploaded_at else None,
            "file_name": attachment.file_name
        }
    except Exception as e:
        raise HTTPException(500, detail=f"Upload failed: {str(e)}")


@router.get("/attachments/{attachment_id}/file")
async def get_journal_attachment_file(
    attachment_id: int,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")

    result = await db.execute(
        select(JournalAttachment).where(
            JournalAttachment.id == attachment_id,
            JournalAttachment.journal_entry.has(JournalEntry.company_id == company_id)
        )
    )
    attachment = result.scalar_one_or_none()
    if not attachment or not attachment.file_url:
        raise HTTPException(404, "Attachment not found")

    async with aiohttp.ClientSession() as session:
        async with session.get(attachment.file_url) as resp:
            if resp.status != 200:
                raise HTTPException(500, "Failed to fetch file")
            content = await resp.read()
            content_type = resp.headers.get('content-type', 'application/octet-stream')
    return Response(content=content, media_type=content_type)


@router.delete("/attachments/{attachment_id}")
async def delete_journal_attachment(
    attachment_id: int,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    if not await _has_permission(company_id, current_user, "edit_journal", db):
        raise HTTPException(403, "No permission to edit journal")

    result = await db.execute(
        select(JournalAttachment).where(
            JournalAttachment.id == attachment_id,
            JournalAttachment.journal_entry.has(JournalEntry.company_id == company_id)
        )
    )
    attachment = result.scalar_one_or_none()
    if not attachment:
        raise HTTPException(404, "Attachment not found")

    await db.delete(attachment)
    await db.commit()
    return {"detail": "Attachment deleted"}