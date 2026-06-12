from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel
from decimal import Decimal

# Производимый товар
class ManufacturedProductBase(BaseModel):
    name: str
    unit: str = "шт"
    price: Decimal = Decimal("0")
    recipe: Optional[str] = None
    sort_order: int = 0

class ManufacturedProductCreate(ManufacturedProductBase):
    pass

class ManufacturedProductUpdate(BaseModel):
    name: Optional[str] = None
    unit: Optional[str] = None
    price: Optional[Decimal] = None
    recipe: Optional[str] = None
    sort_order: Optional[int] = None

class ManufacturedProduct(ManufacturedProductBase):
    id: int
    company_id: int
    current_stock: Decimal
    created_at: datetime
    updated_at: datetime
    is_deleted: bool

    class Config:
        from_attributes = True

# Производственный журнал
class ProductionJournalEntryBase(BaseModel):
    product_id: int
    planned_quantity: Decimal = Decimal("0")
    actual_quantity: Decimal = Decimal("0")
    production_date: datetime
    shift: str = "day"
    worker_name: Optional[str] = None
    notes: Optional[str] = None
    status: str = "completed"

class ProductionJournalEntryCreate(ProductionJournalEntryBase):
    pass

class ProductionJournalEntryUpdate(BaseModel):
    planned_quantity: Optional[Decimal] = None
    actual_quantity: Optional[Decimal] = None
    production_date: Optional[datetime] = None
    shift: Optional[str] = None
    worker_name: Optional[str] = None
    notes: Optional[str] = None
    status: Optional[str] = None

class ProductionJournalEntry(ProductionJournalEntryBase):
    id: int
    company_id: int
    created_by: int
    created_at: datetime
    updated_at: datetime
    product: Optional[ManufacturedProduct] = None

    class Config:
        from_attributes = True

# Транзакция склада ГП
class ProductionStockTransaction(BaseModel):
    id: int
    company_id: int
    product_id: int
    type: str  # production / sale
    quantity: Decimal
    price_per_unit: Optional[Decimal] = None
    journal_entry_id: Optional[int] = None
    transaction_id: Optional[int] = None
    created_at: datetime
    created_by: int

    class Config:
        from_attributes = True

# Рецепт (для фронтенда)
class RecipeItem(BaseModel):
    product_id: int
    product_name: Optional[str] = None
    quantity: float

class ProductionProductWithRecipe(BaseModel):
    product: ManufacturedProduct
    recipe_items: List[RecipeItem]