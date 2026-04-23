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
    employees: List[dict] = []
    

class CompanyResponse(BaseModel):
    id: int
    inn: str
    name: str
    bank_account: str
    manager_full_name: str
    manager_phone: str
    total_balance: float
    employees_credentials: List[dict] = []
    current_user_role: Optional[str] = None  
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
    icon: str = "📁"

class CategoryResponse(BaseModel):
    id: int
    name: str
    type: TransactionType
    is_system: bool
    icon: str = "📁"   
    class Config:
        from_attributes = True

# Transaction
# Transaction
class TransactionItemCreate(BaseModel):
    product_id: int
    quantity: float
    price_per_unit: Optional[float] = None

class TransactionCreate(BaseModel):
    type: TransactionType
    amount: float
    date: datetime
    account_id: int
    category_id: Optional[int] = None
    description: Optional[str] = None
    transfer_to_account_id: Optional[int] = None
    delete_attachment: bool = False
    items: Optional[List[TransactionItemCreate]] = []
    counterparty: Optional[str] = None  
    showcase_item_id: Optional[int] = None
    
class TransactionItemResponse(BaseModel):
    product_id: int
    product_name: str
    quantity: float
    price_per_unit: Optional[float] = None
    total: Optional[float] = None

class TransactionResponse(BaseModel):
    id: int
    type: str
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
    creator_name: Optional[str] = None
    updater_name: Optional[str] = None
    number: int  
    items: List[TransactionItemResponse] = []
    counterparty: Optional[str] = None  
    showcase_item_id: Optional[int] = None
    class Config:
        from_attributes = True

class UpdateMemberRole(BaseModel):
    role_in_company: str        

class SetManagerRequest(BaseModel):
    user_id: int

class ShowcaseItemCreate(BaseModel):
    name: str
    price: float
    sort_order: Optional[int] = 0
    image_url: Optional[str] = None
    recipe: Optional[str] = None  # JSON
    category_id: Optional[int] = None

class ShowcaseItemUpdate(BaseModel):
    name: Optional[str] = None
    price: Optional[float] = None
    sort_order: Optional[int] = None
    image_url: Optional[str] = None
    recipe: Optional[str] = None
    category_id: Optional[int] = None

class ShowcaseItemResponse(BaseModel):
    id: int
    company_id: int
    name: str
    price: float
    sort_order: int
    image_url: Optional[str]
    recipe: Optional[str]
    created_at: datetime
    updated_at: datetime
    category_id: Optional[int] = None
    class Config:
        from_attributes = True    