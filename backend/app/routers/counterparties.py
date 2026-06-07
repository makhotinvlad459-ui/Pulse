from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List
from pydantic import BaseModel
from datetime import datetime
import os
import uuid
from fastapi import UploadFile, File
from firebase_admin import storage
from app.models import CounterpartyDocument

from app.database import get_db
from app.models import User, Company, Counterparty, CompanyMember, UserRole
from app.deps import get_current_user

router = APIRouter(prefix="/counterparties", tags=["counterparties"], redirect_slashes=False)

MAX_FILE_SIZE = 10 * 1024 * 1024
ALLOWED_EXTENSIONS = {'.jpg', '.jpeg', '.png', '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.txt'}

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

@router.get("/search")
async def search_counterparties(
    company_id: int,
    q: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    stmt = select(Counterparty.name).where(
        Counterparty.company_id == company_id,
        Counterparty.name.ilike(f"%{q}%")
    ).limit(10)
    result = await db.execute(stmt)
    names = [row[0] for row in result.all()]
    return names

@router.get("/{counterparty_id}/documents")
async def get_counterparty_documents(
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
    
    result = await db.execute(
        select(CounterpartyDocument).where(CounterpartyDocument.counterparty_id == counterparty_id)
        .order_by(CounterpartyDocument.uploaded_at.desc())
    )
    return result.scalars().all()


# Загрузка документа для контрагента
@router.post("/{counterparty_id}/documents")
async def upload_counterparty_document(
    counterparty_id: int,
    company_id: int,
    file: UploadFile = File(...),
    description: str | None = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    cp = await db.get(Counterparty, counterparty_id)
    if not cp or cp.company_id != company_id:
        raise HTTPException(404, "Counterparty not found")
    
    file.file.seek(0, 2)
    size = file.file.tell()
    if size > MAX_FILE_SIZE:
        raise HTTPException(400, detail="File too large (max 10 MB)")
    await file.seek(0)
    
    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(400, detail="File type not allowed")
    
    try:
        contents = await file.read()
        bucket = storage.bucket()
        blob_path = f"companies/{company_id}/counterparties/{counterparty_id}/{uuid.uuid4()}{ext}"
        blob = bucket.blob(blob_path)
        blob.upload_from_string(contents, content_type=file.content_type)
        blob.make_public()
        public_url = blob.public_url
        
        doc = CounterpartyDocument(
            counterparty_id=counterparty_id,
            file_url=public_url,
            uploaded_by=current_user.id,
            file_name=file.filename,
            description=description
        )
        db.add(doc)
        await db.commit()
        await db.refresh(doc)
        return {
            "id": doc.id,
            "file_url": doc.file_url,
            "file_name": doc.file_name,
            "uploaded_at": doc.uploaded_at,
            "description": doc.description
        }
    except Exception as e:
        raise HTTPException(500, detail=f"Upload failed: {str(e)}")

# Получение файла документа (прокси)
@router.get("/documents/{document_id}/file")
async def get_counterparty_document_file(
    document_id: int,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    import aiohttp
    from fastapi.responses import Response
    
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    
    result = await db.execute(
        select(CounterpartyDocument).where(
            CounterpartyDocument.id == document_id,
            CounterpartyDocument.counterparty.has(Counterparty.company_id == company_id)
        )
    )
    doc = result.scalar_one_or_none()
    if not doc or not doc.file_url:
        raise HTTPException(404, "Document not found")
    
    async with aiohttp.ClientSession() as session:
        async with session.get(doc.file_url) as resp:
            if resp.status != 200:
                raise HTTPException(500, "Failed to fetch file")
            content = await resp.read()
            content_type = resp.headers.get('content-type', 'application/octet-stream')
    return Response(content=content, media_type=content_type)

# Удаление документа
@router.delete("/documents/{document_id}")
async def delete_counterparty_document(
    document_id: int,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _check_company_access(company_id, current_user, db):
        raise HTTPException(403, "Access denied")
    
    result = await db.execute(
        select(CounterpartyDocument).where(
            CounterpartyDocument.id == document_id,
            CounterpartyDocument.counterparty.has(Counterparty.company_id == company_id)
        )
    )
    doc = result.scalar_one_or_none()
    if not doc:
        raise HTTPException(404, "Document not found")
    
    await db.delete(doc)
    await db.commit()
    return {"detail": "Deleted"}

# Получение журнальных записей по контрагенту (из журнала, где counterparty равен имени контрагента)
@router.get("/{counterparty_id}/journal")
async def get_counterparty_journal_entries(
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
    
    from sqlalchemy.orm import selectinload
    from app.models import JournalEntry
    
    stmt = select(JournalEntry).where(
        JournalEntry.company_id == company_id,
        JournalEntry.counterparty == cp.name
    ).order_by(JournalEntry.datetime_start.desc()).options(selectinload(JournalEntry.attachments))
    
    result = await db.execute(stmt)
    return result.scalars().all()