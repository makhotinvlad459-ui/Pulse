from pydantic import BaseModel
from datetime import datetime
from typing import Optional, List
from enum import Enum

class UserRole(str, Enum):
    FOUNDER = "founder"
    EMPLOYEE = "employee"

class TransactionType(str, Enum):
    INCOME = "income"
    EXPENSE = "expense"
    TRANSFER = "transfer"

# Company
class CompanyCreate(BaseModel):
    inn: str
    name: str
    bank_account: str
    manager_full_name: str
    manager_phone: str
    employees: List[dict] = []  # каждый: {"full_name": str, "phone": str}

class CompanyResponse(BaseModel):
    id: int
    inn: str
    name: str
    bank_account: str
    manager_full_name: str
    manager_phone: str
    total_balance: float  # сумма наличные + банк по этой компании
    class Config:
        from_attributes = True

# Account
class AccountCreate(BaseModel):
    name: str
    type: str  # 'cash', 'bank', 'other'
    include_in_profit_loss: bool = True

class AccountResponse(BaseModel):
    id: int
    name: str
    type: str
    include_in_profit_loss: bool
    balance: float
    class Config:
        from_attributes = True

# Category
class CategoryCreate(BaseModel):
    name: str
    type: TransactionType

class CategoryResponse(BaseModel):
    id: int
    name: str
    type: TransactionType
    is_system: bool
    class Config:
        from_attributes = True

# Transaction
class TransactionCreate(BaseModel):
    type: TransactionType
    amount: float
    date: datetime
    account_id: int
    category_id: Optional[int] = None
    description: Optional[str] = None
    transfer_to_account_id: Optional[int] = None  # только для перевода

class TransactionResponse(BaseModel):
    id: int
    type: TransactionType
    amount: float
    date: datetime
    account_id: int
    category_id: Optional[int]
    description: Optional[str]
    attachment_url: Optional[str]
    created_by: int
    updated_by: Optional[int]
    is_deleted: bool
    deleted_by: Optional[int]
    deleted_at: Optional[datetime]
    transfer_to_account_id: Optional[int]
    class Config:
        from_attributes = True