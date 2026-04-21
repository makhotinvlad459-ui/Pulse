from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, func, delete
from typing import List, Optional
from datetime import datetime
from sqlalchemy.orm import selectinload
import os
import shutil
from fastapi.responses import FileResponse
from decimal import Decimal

from app.database import get_db
from app.models import User, Company, Account, Category, Transaction, TransactionType, CompanyMember, UserRole, Product, TransactionItem
from app.schemas import TransactionCreate, TransactionResponse, TransactionItemResponse
from app.deps import get_current_user

router = APIRouter(prefix="/transactions", tags=["transactions"])

MAX_FILE_SIZE = 10 * 1024 * 1024
ALLOWED_EXTENSIONS = {'.jpg', '.jpeg', '.png', '.pdf'}

async def recalc_account_balance(account_id: int, db: AsyncSession):
    income = await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0))
        .where(Transaction.account_id == account_id, Transaction.type == 'income', Transaction.is_deleted == False)
    )
    total_income = float(income.scalar())
    expense = await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0))
        .where(Transaction.account_id == account_id, Transaction.type == 'expense', Transaction.is_deleted == False)
    )
    total_expense = float(expense.scalar())
    transfer_out = await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0))
        .where(Transaction.account_id == account_id, Transaction.type == 'transfer', Transaction.is_deleted == False)
    )
    total_transfer_out = float(transfer_out.scalar())
    transfer_in = await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0))
        .where(Transaction.transfer_to_account_id == account_id, Transaction.type == 'transfer', Transaction.is_deleted == False)
    )
    total_transfer_in = float(transfer_in.scalar())
    balance = total_income - total_expense - total_transfer_out + total_transfer_in
    await db.execute(update(Account).where(Account.id == account_id).values(balance=balance))

@router.post("/", response_model=TransactionResponse)
async def create_transaction(
    trans_data: TransactionCreate,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Проверка доступа к компании
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    # Проверка счёта
    result = await db.execute(select(Account).where(Account.id == trans_data.account_id, Account.company_id == company_id))
    account = result.scalar_one_or_none()
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")
    
    is_transfer = (trans_data.type.value == 'transfer')
    
    # Валидация перевода
    if is_transfer:
        if trans_data.transfer_to_account_id is None:
            raise HTTPException(status_code=400, detail="Transfer requires transfer_to_account_id")
        result = await db.execute(select(Account).where(Account.id == trans_data.transfer_to_account_id, Account.company_id == company_id))
        target_account = result.scalar_one_or_none()
        if not target_account:
            raise HTTPException(status_code=404, detail="Target account not found")
        if trans_data.account_id == trans_data.transfer_to_account_id:
            raise HTTPException(status_code=400, detail="Cannot transfer to the same account")
    
    # Категории для дохода/расхода (если нет товаров)
    if not is_transfer and not trans_data.items:
        if not trans_data.category_id:
            result = await db.execute(select(Category).where(Category.company_id == company_id, Category.is_system == True))
            default_cat = result.scalar_one_or_none()
            if not default_cat:
                default_cat = Category(
                    company_id=company_id,
                    name="Без категории",
                    type=trans_data.type.value,
                    is_system=True,
                    created_by=current_user.id
                )
                db.add(default_cat)
                await db.flush()
            trans_data.category_id = default_cat.id
        else:
            result = await db.execute(select(Category).where(Category.id == trans_data.category_id, Category.company_id == company_id))
            if not result.scalar_one_or_none():
                raise HTTPException(status_code=404, detail="Category not found")
    
    # Генерация номера операции
    last_num_result = await db.execute(select(func.max(Transaction.number)).where(Transaction.company_id == company_id))
    last_num = last_num_result.scalar() or 0
    new_number = last_num + 1
    
    # Приводим дату
    if trans_data.date.tzinfo is not None:
        trans_data.date = trans_data.date.replace(tzinfo=None)
    
    # Создаём транзакцию
    new_trans = Transaction(
        company_id=company_id,
        account_id=trans_data.account_id,
        type=trans_data.type.value,
        amount=trans_data.amount,
        date=trans_data.date,
        category_id=trans_data.category_id if not is_transfer and not trans_data.items else None,
        description=trans_data.description,
        created_by=current_user.id,
        transfer_to_account_id=trans_data.transfer_to_account_id if is_transfer else None,
        number=new_number,
        counterparty=trans_data.counterparty   # <-- добавлено
    )
    db.add(new_trans)
    await db.flush()
    
    # Обработка товаров и сохранение в transaction_items
    if not is_transfer and trans_data.items:
        for item in trans_data.items:
            # Проверяем товар
            prod_result = await db.execute(select(Product).where(Product.id == item.product_id, Product.company_id == company_id))
            product = prod_result.scalar_one_or_none()
            if not product:
                raise HTTPException(status_code=404, detail=f"Product {item.product_id} not found")
            # Обновляем остаток на складе
            if trans_data.type.value == 'income':
                # Приход (продажа) – списываем товар
                if product.current_quantity < Decimal(str(item.quantity)):
                    raise HTTPException(status_code=400, detail=f"Insufficient stock for {product.name}")
                product.current_quantity -= Decimal(str(item.quantity))
            else:  # expense
                # Расход (покупка) – добавляем товар
                product.current_quantity += Decimal(str(item.quantity))
            # Сохраняем запись в transaction_items с ценой за единицу
            trans_item = TransactionItem(
                transaction_id=new_trans.id,
                product_id=item.product_id,
                quantity=item.quantity,
                price_per_unit=item.price_per_unit
            )
            db.add(trans_item)
    
    # Пересчёт балансов счетов
    await recalc_account_balance(new_trans.account_id, db)
    if is_transfer and new_trans.transfer_to_account_id is not None:
        await recalc_account_balance(new_trans.transfer_to_account_id, db)
    
    await db.commit()
    await db.refresh(new_trans)
    await db.refresh(new_trans, attribute_names=['creator', 'updater'])
    
    # Загружаем товары для ответа
    items_result = await db.execute(
        select(TransactionItem).where(TransactionItem.transaction_id == new_trans.id)
        .options(selectinload(TransactionItem.product))
    )
    items = items_result.scalars().all()
    items_response = [
        TransactionItemResponse(
            product_id=it.product_id,
            product_name=it.product.name,
            quantity=it.quantity,
            price_per_unit=it.price_per_unit,
            total=it.quantity * (it.price_per_unit or 0)
        ) for it in items
    ]
    
    return TransactionResponse(
        id=new_trans.id,
        type=new_trans.type,
        amount=new_trans.amount,
        date=new_trans.date,
        account_id=new_trans.account_id,
        category_id=new_trans.category_id,
        description=new_trans.description,
        attachment_url=new_trans.attachment_url,
        created_by=new_trans.created_by,
        updated_by=new_trans.updated_by,
        is_deleted=new_trans.is_deleted,
        deleted_by=new_trans.deleted_by,
        deleted_at=new_trans.deleted_at,
        transfer_to_account_id=new_trans.transfer_to_account_id,
        creator_name=new_trans.creator.display_name if new_trans.creator else None,
        updater_name=new_trans.updater.display_name if new_trans.updater else None,
        number=new_trans.number,
        items=items_response,
        counterparty=new_trans.counterparty   # <-- добавлено
    )

@router.get("/", response_model=List[TransactionResponse])
async def get_transactions(
    company_id: int,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    type: Optional[TransactionType] = None,
    category_id: Optional[int] = None,
    account_id: Optional[int] = None,
    include_deleted: bool = False,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    query = select(Transaction).where(Transaction.company_id == company_id)
    if not include_deleted:
        query = query.where(Transaction.is_deleted == False)
    if start_date:
        if start_date.tzinfo:
            start_date = start_date.replace(tzinfo=None)
        query = query.where(Transaction.date >= start_date)
    if end_date:
        if end_date.tzinfo:
            end_date = end_date.replace(tzinfo=None)
        query = query.where(Transaction.date <= end_date)
    if type:
        query = query.where(Transaction.type == type.value)
    if category_id:
        query = query.where(Transaction.category_id == category_id)
    if account_id:
        query = query.where(Transaction.account_id == account_id)
    
    query = query.order_by(Transaction.date.desc())
    query = query.options(
        selectinload(Transaction.creator),
        selectinload(Transaction.updater),
        selectinload(Transaction.items).selectinload(TransactionItem.product)
    )
    result = await db.execute(query)
    transactions = result.scalars().all()
    
    response = []
    for t in transactions:
        items_response = [
            TransactionItemResponse(
                product_id=it.product_id,
                product_name=it.product.name,
                quantity=it.quantity,
                price_per_unit=it.price_per_unit,
                total=it.quantity * (it.price_per_unit or 0)
            ) for it in t.items
        ]
        response.append(TransactionResponse(
            id=t.id,
            type=t.type,
            amount=t.amount,
            date=t.date,
            account_id=t.account_id,
            category_id=t.category_id,
            description=t.description,
            attachment_url=t.attachment_url,
            created_by=t.created_by,
            updated_by=t.updated_by,
            is_deleted=t.is_deleted,
            deleted_by=t.deleted_by,
            deleted_at=t.deleted_at,
            transfer_to_account_id=t.transfer_to_account_id,
            creator_name=t.creator.display_name if t.creator else None,
            updater_name=t.updater.display_name if t.updater else None,
            number=t.number,
            items=items_response,
            counterparty=t.counterparty   # <-- добавлено
        ))
    return response

@router.get("/{transaction_id}", response_model=TransactionResponse)
async def get_transaction(
    transaction_id: int,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    query = select(Transaction).where(Transaction.id == transaction_id, Transaction.company_id == company_id)
    query = query.options(
        selectinload(Transaction.creator),
        selectinload(Transaction.updater),
        selectinload(Transaction.items).selectinload(TransactionItem.product)
    )
    result = await db.execute(query)
    t = result.scalar_one_or_none()
    if not t:
        raise HTTPException(status_code=404, detail="Transaction not found")
    
    items_response = [
        TransactionItemResponse(
            product_id=it.product_id,
            product_name=it.product.name,
            quantity=it.quantity,
            price_per_unit=it.price_per_unit,
            total=it.quantity * (it.price_per_unit or 0)
        ) for it in t.items
    ]
    return TransactionResponse(
        id=t.id,
        type=t.type,
        amount=t.amount,
        date=t.date,
        account_id=t.account_id,
        category_id=t.category_id,
        description=t.description,
        attachment_url=t.attachment_url,
        created_by=t.created_by,
        updated_by=t.updated_by,
        is_deleted=t.is_deleted,
        deleted_by=t.deleted_by,
        deleted_at=t.deleted_at,
        transfer_to_account_id=t.transfer_to_account_id,
        creator_name=t.creator.display_name if t.creator else None,
        updater_name=t.updater.display_name if t.updater else None,
        number=t.number,
        items=items_response,
        counterparty=t.counterparty   # <-- добавлено
    )

@router.patch("/{transaction_id}", response_model=TransactionResponse)
async def update_transaction(
    transaction_id: int,
    company_id: int,
    trans_data: TransactionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    result = await db.execute(select(Transaction).where(Transaction.id == transaction_id, Transaction.company_id == company_id))
    transaction = result.scalar_one_or_none()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    
    old_account_id = transaction.account_id
    old_transfer_to = transaction.transfer_to_account_id
    
    if trans_data.date.tzinfo is not None:
        trans_data.date = trans_data.date.replace(tzinfo=None)
    
    # Обновляем основные поля
    transaction.account_id = trans_data.account_id
    transaction.type = trans_data.type.value
    transaction.amount = trans_data.amount
    transaction.date = trans_data.date
    transaction.category_id = trans_data.category_id
    transaction.description = trans_data.description
    transaction.updated_by = current_user.id
    transaction.counterparty = trans_data.counterparty   # <-- добавлено
    
    is_transfer = (trans_data.type.value == 'transfer')
    if is_transfer:
        transaction.transfer_to_account_id = trans_data.transfer_to_account_id
    else:
        transaction.transfer_to_account_id = None

    if trans_data.delete_attachment:
        if transaction.attachment_url and os.path.exists(transaction.attachment_url):
            try:
                os.remove(transaction.attachment_url)
            except Exception as e:
                print(f"Error deleting file: {e}")
        transaction.attachment_url = None
        transaction.attachment_uploaded_at = None
    
    await db.flush()
    
    # Обновление товаров: удаляем старые, добавляем новые
    old_items_result = await db.execute(
        select(TransactionItem).where(TransactionItem.transaction_id == transaction_id)
        .options(selectinload(TransactionItem.product))
    )
    old_items = old_items_result.scalars().all()
    for old_item in old_items:
        product = old_item.product
        if transaction.type == 'income':
            product.current_quantity += Decimal(str(old_item.quantity))
        else:
            product.current_quantity -= Decimal(str(old_item.quantity))
    
    await db.execute(delete(TransactionItem).where(TransactionItem.transaction_id == transaction_id))
    
    if not is_transfer and trans_data.items:
        for item in trans_data.items:
            prod_result = await db.execute(select(Product).where(Product.id == item.product_id, Product.company_id == company_id))
            product = prod_result.scalar_one_or_none()
            if not product:
                raise HTTPException(status_code=404, detail=f"Product {item.product_id} not found")
            if trans_data.type.value == 'income':
                if product.current_quantity < Decimal(str(item.quantity)):
                    raise HTTPException(status_code=400, detail=f"Insufficient stock for {product.name}")
                product.current_quantity -= Decimal(str(item.quantity))
            else:
                product.current_quantity += Decimal(str(item.quantity))
            trans_item = TransactionItem(
                transaction_id=transaction_id,
                product_id=item.product_id,
                quantity=item.quantity,
                price_per_unit=item.price_per_unit
            )
            db.add(trans_item)
    
    await recalc_account_balance(old_account_id, db)
    if old_transfer_to:
        await recalc_account_balance(old_transfer_to, db)
    await recalc_account_balance(transaction.account_id, db)
    if transaction.transfer_to_account_id:
        await recalc_account_balance(transaction.transfer_to_account_id, db)
    
    await db.commit()
    await db.refresh(transaction)
    await db.refresh(transaction, attribute_names=['creator', 'updater'])
    
    items_result = await db.execute(
        select(TransactionItem).where(TransactionItem.transaction_id == transaction_id)
        .options(selectinload(TransactionItem.product))
    )
    items = items_result.scalars().all()
    items_response = [
        TransactionItemResponse(
            product_id=it.product_id,
            product_name=it.product.name,
            quantity=it.quantity,
            price_per_unit=it.price_per_unit,
            total=it.quantity * (it.price_per_unit or 0)
        ) for it in items
    ]
    
    return TransactionResponse(
        id=transaction.id,
        type=transaction.type,
        amount=transaction.amount,
        date=transaction.date,
        account_id=transaction.account_id,
        category_id=transaction.category_id,
        description=transaction.description,
        attachment_url=transaction.attachment_url,
        created_by=transaction.created_by,
        updated_by=transaction.updated_by,
        is_deleted=transaction.is_deleted,
        deleted_by=transaction.deleted_by,
        deleted_at=transaction.deleted_at,
        transfer_to_account_id=transaction.transfer_to_account_id,
        creator_name=transaction.creator.display_name if transaction.creator else None,
        updater_name=transaction.updater.display_name if transaction.updater else None,
        number=transaction.number,
        items=items_response,
        counterparty=transaction.counterparty
    )


@router.delete("/{transaction_id}")
async def delete_transaction(
    transaction_id: int,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    result = await db.execute(select(Transaction).where(Transaction.id == transaction_id, Transaction.company_id == company_id))
    transaction = result.scalar_one_or_none()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    
    # Загружаем товары транзакции
    items_result = await db.execute(
        select(TransactionItem).where(TransactionItem.transaction_id == transaction_id)
        .options(selectinload(TransactionItem.product))
    )
    items = items_result.scalars().all()
    
    if current_user.role == UserRole.FOUNDER:
        # Полное удаление – откатываем остатки
        for item in items:
            product = item.product
            if transaction.type == 'income':
                product.current_quantity += Decimal(str(item.quantity))
            else:  # expense
                product.current_quantity -= Decimal(str(item.quantity))
        
        if transaction.attachment_url and os.path.exists(transaction.attachment_url):
            try:
                os.remove(transaction.attachment_url)
            except Exception as e:
                print(f"Error deleting file: {e}")
        await db.delete(transaction)
        await db.commit()
        await recalc_account_balance(transaction.account_id, db)
        if transaction.transfer_to_account_id:
            await recalc_account_balance(transaction.transfer_to_account_id, db)
        await db.commit()
        return {"detail": "Transaction permanently deleted"}
    else:
        if transaction.is_deleted:
            raise HTTPException(status_code=400, detail="Transaction already deleted")
        transaction.is_deleted = True
        transaction.deleted_by = current_user.id
        transaction.deleted_at = datetime.utcnow()
        await db.flush()
        await recalc_account_balance(transaction.account_id, db)
        if transaction.transfer_to_account_id:
            await recalc_account_balance(transaction.transfer_to_account_id, db)
        await db.commit()
        return {"detail": "Transaction soft-deleted"}

@router.post("/{transaction_id}/restore")
async def restore_transaction(
    transaction_id: int,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    result = await db.execute(select(Transaction).where(Transaction.id == transaction_id, Transaction.company_id == company_id))
    transaction = result.scalar_one_or_none()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    
    if not transaction.is_deleted:
        raise HTTPException(status_code=400, detail="Transaction is not deleted")
    
    transaction.is_deleted = False
    transaction.deleted_by = None
    transaction.deleted_at = None
    
    await db.flush()
    await recalc_account_balance(transaction.account_id, db)
    if transaction.transfer_to_account_id:
        await recalc_account_balance(transaction.transfer_to_account_id, db)
    
    await db.commit()
    return {"detail": "Transaction restored"}

@router.post("/{transaction_id}/upload")
async def upload_transaction_photo(
    transaction_id: int,
    company_id: int,
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")

    result = await db.execute(select(Transaction).where(Transaction.id == transaction_id, Transaction.company_id == company_id))
    transaction = result.scalar_one_or_none()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")

    if transaction.attachment_url and os.path.exists(transaction.attachment_url):
        try:
            os.remove(transaction.attachment_url)
        except Exception as e:
            print(f"Error deleting old file: {e}")

    file.file.seek(0, 2)
    size = file.file.tell()
    if size > MAX_FILE_SIZE:
        raise HTTPException(status_code=400, detail=f"File too large (max {MAX_FILE_SIZE // (1024*1024)} MB)")
    await file.seek(0)

    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=400, detail="Only JPG, PNG, PDF files are allowed")

    upload_dir = f"uploads/company_{company_id}"
    os.makedirs(upload_dir, exist_ok=True)

    timestamp = int(datetime.utcnow().timestamp())
    safe_filename = f"{transaction_id}_{timestamp}{ext}"
    file_path = os.path.join(upload_dir, safe_filename)

    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    transaction.attachment_url = file_path
    transaction.attachment_uploaded_at = datetime.utcnow()
    await db.commit()

    return {"detail": "File uploaded", "url": file_path}

@router.get("/{transaction_id}/photo")
async def get_transaction_photo(
    transaction_id: int,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    company = result.scalar_one_or_none()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    result = await db.execute(select(Transaction).where(Transaction.id == transaction_id, Transaction.company_id == company_id))
    transaction = result.scalar_one_or_none()
    if not transaction or not transaction.attachment_url:
        raise HTTPException(status_code=404, detail="File not found")
    
    file_path = transaction.attachment_url
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="File not found")
    
    return FileResponse(file_path)