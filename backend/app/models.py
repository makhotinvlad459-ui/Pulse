from datetime import datetime
from sqlalchemy import String, Boolean, DateTime, ForeignKey, Numeric, Enum, Integer, CheckConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from enum import Enum as PyEnum
from app.database import Base
from sqlalchemy import UniqueConstraint

class UserRole(PyEnum):
    FOUNDER = "founder"
    EMPLOYEE = "employee"
    SUPERADMIN = "superadmin"

class TransactionType(PyEnum):
    INCOME = "income"
    EXPENSE = "expense"
    TRANSFER = "transfer"

class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    phone: Mapped[str] = mapped_column(String(20), unique=True, index=True)
    full_name: Mapped[str] = mapped_column(String(255))
    password_hash: Mapped[str] = mapped_column(String(255))
    role: Mapped[UserRole] = mapped_column(Enum(UserRole), default=UserRole.EMPLOYEE)
    subscription_until: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    soft_delete_retention_days: Mapped[int] = mapped_column(Integer, default=15)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    last_login: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    # relationships
    companies_founded: Mapped[list["Company"]] = relationship("Company", back_populates="founder", foreign_keys="Company.founder_id")
    memberships: Mapped[list["CompanyMember"]] = relationship("CompanyMember", foreign_keys="CompanyMember.user_id", back_populates="user")
    invited_members: Mapped[list["CompanyMember"]] = relationship("CompanyMember", foreign_keys="CompanyMember.invited_by", back_populates="inviter")
    created_categories: Mapped[list["Category"]] = relationship("Category", foreign_keys="Category.created_by", back_populates="creator")
    created_transactions: Mapped[list["Transaction"]] = relationship("Transaction", foreign_keys="Transaction.created_by", back_populates="creator")
    updated_transactions: Mapped[list["Transaction"]] = relationship("Transaction", foreign_keys="Transaction.updated_by", back_populates="updater")
    deleted_transactions: Mapped[list["Transaction"]] = relationship("Transaction", foreign_keys="Transaction.deleted_by", back_populates="deleter")
    chat_messages: Mapped[list["ChatMessage"]] = relationship(back_populates="user")
    transaction_comments: Mapped[list["TransactionComment"]] = relationship(back_populates="user")

    @property
    def display_name(self) -> str:
        """Возвращает 'Основатель' для учредителя, иначе full_name"""
        if self.role == UserRole.FOUNDER:
            return "Основатель"
        return self.full_name
    
class Company(Base):
    __tablename__ = "companies"

    id: Mapped[int] = mapped_column(primary_key=True)
    founder_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    inn: Mapped[str] = mapped_column(String(12), index=True)
    name: Mapped[str] = mapped_column(String(255))
    bank_account: Mapped[str] = mapped_column(String(34))
    manager_full_name: Mapped[str] = mapped_column(String(255))
    manager_phone: Mapped[str] = mapped_column(String(20))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # relationships
    founder: Mapped["User"] = relationship("User", back_populates="companies_founded")
    members: Mapped[list["CompanyMember"]] = relationship("CompanyMember", back_populates="company", cascade="all, delete-orphan")
    accounts: Mapped[list["Account"]] = relationship("Account", back_populates="company", cascade="all, delete-orphan")
    categories: Mapped[list["Category"]] = relationship("Category", back_populates="company", cascade="all, delete-orphan")
    transactions: Mapped[list["Transaction"]] = relationship("Transaction", back_populates="company", cascade="all, delete-orphan")
    chat_messages: Mapped[list["ChatMessage"]] = relationship(back_populates="company", cascade="all, delete-orphan")
    tasks: Mapped[list["Task"]] = relationship("Task", back_populates="company", cascade="all, delete-orphan")
    products: Mapped[list["Product"]] = relationship(back_populates="company", cascade="all, delete-orphan")
    dishes: Mapped[list["Dish"]] = relationship(back_populates="company", cascade="all, delete-orphan")

class CompanyMember(Base):
    __tablename__ = "company_members"
    __table_args__ = (CheckConstraint("role_in_company IN ('manager', 'accountant', 'employee')"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    company_id: Mapped[int] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"))
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    role_in_company: Mapped[str] = mapped_column(String(50), default="employee")
    invited_by: Mapped[int] = mapped_column(ForeignKey("users.id"))
    joined_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # relationships
    company: Mapped["Company"] = relationship("Company", back_populates="members")
    user: Mapped["User"] = relationship("User", foreign_keys=[user_id], back_populates="memberships")
    inviter: Mapped["User"] = relationship("User", foreign_keys=[invited_by], back_populates="invited_members")

class Account(Base):
    __tablename__ = "accounts"
    __table_args__ = (CheckConstraint("type IN ('cash', 'bank', 'other')"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    company_id: Mapped[int] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"))
    name: Mapped[str] = mapped_column(String(100))
    type: Mapped[str] = mapped_column(String(20))
    include_in_profit_loss: Mapped[bool] = mapped_column(Boolean, default=True)
    balance: Mapped[float] = mapped_column(Numeric(15, 2), default=0.0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # relationships
    company: Mapped["Company"] = relationship("Company", back_populates="accounts")
    transactions_from: Mapped[list["Transaction"]] = relationship("Transaction", foreign_keys="Transaction.account_id", back_populates="account")
    transactions_to: Mapped[list["Transaction"]] = relationship("Transaction", foreign_keys="Transaction.transfer_to_account_id", back_populates="target_account")

class Category(Base):
    __tablename__ = "categories"

    id: Mapped[int] = mapped_column(primary_key=True)
    company_id: Mapped[int] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"))
    name: Mapped[str] = mapped_column(String(100))
    type: Mapped[str] = mapped_column(String(20))
    is_system: Mapped[bool] = mapped_column(Boolean, default=False)
    created_by: Mapped[int] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    icon: Mapped[str] = mapped_column(String(10), default="📁")


    # relationships
    company: Mapped["Company"] = relationship("Company", back_populates="categories")
    creator: Mapped["User"] = relationship("User", foreign_keys=[created_by], back_populates="created_categories")
    transactions: Mapped[list["Transaction"]] = relationship("Transaction", back_populates="category")

class Transaction(Base):
    __tablename__ = "transactions"

    id: Mapped[int] = mapped_column(primary_key=True)
    company_id: Mapped[int] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"))
    account_id: Mapped[int] = mapped_column(ForeignKey("accounts.id"))
    type: Mapped[str] = mapped_column(String(20))
    amount: Mapped[float] = mapped_column(Numeric(15, 2))
    date: Mapped[datetime] = mapped_column(DateTime, index=True)
    category_id: Mapped[int | None] = mapped_column(ForeignKey("categories.id"), nullable=True)
    description: Mapped[str | None] = mapped_column(String(500), nullable=True)
    attachment_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_by: Mapped[int] = mapped_column(ForeignKey("users.id"))
    updated_by: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False)
    deleted_by: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    transfer_to_account_id: Mapped[int | None] = mapped_column(ForeignKey("accounts.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    attachment_uploaded_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    
    # relationships
    company: Mapped["Company"] = relationship(back_populates="transactions")
    account: Mapped["Account"] = relationship(foreign_keys=[account_id], back_populates="transactions_from")
    target_account: Mapped["Account"] = relationship(foreign_keys=[transfer_to_account_id], back_populates="transactions_to")
    category: Mapped["Category"] = relationship(back_populates="transactions")
    comments: Mapped[list["TransactionComment"]] = relationship(back_populates="transaction", cascade="all, delete-orphan")
    creator: Mapped["User"] = relationship(foreign_keys=[created_by], back_populates="created_transactions")
    updater: Mapped["User"] = relationship(foreign_keys=[updated_by], back_populates="updated_transactions")
    deleter: Mapped["User"] = relationship(foreign_keys=[deleted_by], back_populates="deleted_transactions")

class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id: Mapped[int] = mapped_column(primary_key=True)
    company_id: Mapped[int] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"))
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    message: Mapped[str] = mapped_column(String(1000))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    edited: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)  # добавлено
    updated_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True) # добавлено

    # relationships
    company: Mapped["Company"] = relationship(back_populates="chat_messages")
    user: Mapped["User"] = relationship(back_populates="chat_messages")


class TransactionComment(Base):
    __tablename__ = "transaction_comments"

    id: Mapped[int] = mapped_column(primary_key=True)
    transaction_id: Mapped[int] = mapped_column(ForeignKey("transactions.id", ondelete="CASCADE"))
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    comment: Mapped[str] = mapped_column(String(500))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # relationships
    transaction: Mapped["Transaction"] = relationship(back_populates="comments")
    user: Mapped["User"] = relationship(back_populates="transaction_comments")

class TaskStatus(PyEnum):
    PENDING = "pending"      # ожидает принятия
    ACCEPTED = "accepted"    # принята
    COMPLETED = "completed"  # исполнена
    FAILED = "failed"        # провалена

class Task(Base):
    __tablename__ = "tasks"

    id: Mapped[int] = mapped_column(primary_key=True)
    company_id: Mapped[int] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"))
    author_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    assignee_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=True)  # кому назначена
    title: Mapped[str] = mapped_column(String(255))
    description: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    status: Mapped[TaskStatus] = mapped_column(Enum(TaskStatus), default=TaskStatus.PENDING)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    deadline: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    # relationships
    company: Mapped["Company"] = relationship(back_populates="tasks")
    author: Mapped["User"] = relationship(foreign_keys=[author_id])
    assignee: Mapped["User"] = relationship(foreign_keys=[assignee_id])    

class UserChatVisit(Base):
    __tablename__ = "user_chat_visits"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    company_id: Mapped[int] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"))
    last_visit_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (UniqueConstraint("user_id", "company_id", name="uq_user_company_visit"),)

class Product(Base):
    __tablename__ = "products"

    id: Mapped[int] = mapped_column(primary_key=True)
    company_id: Mapped[int] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"))
    name: Mapped[str] = mapped_column(String(100))
    unit: Mapped[str] = mapped_column(String(20))  # 'kg', 'liter', 'piece', 'g', 'ml'
    current_quantity: Mapped[float] = mapped_column(Numeric(15, 3), default=0.0)
    price_per_unit: Mapped[float] = mapped_column(Numeric(15, 2), nullable=True)  # закупочная цена
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # relationships
    company: Mapped["Company"] = relationship(back_populates="products")
    # recipe_items: Mapped[list["RecipeItem"]] = relationship(back_populates="product", cascade="all, delete-orphan")
    # stock_entries: Mapped[list["StockEntry"]] = relationship(back_populates="product", cascade="all, delete-orphan")

class Dish(Base):
    __tablename__ = "dishes"

    id: Mapped[int] = mapped_column(primary_key=True)
    company_id: Mapped[int] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"))
    name: Mapped[str] = mapped_column(String(100))
    price: Mapped[float] = mapped_column(Numeric(15, 2), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    company: Mapped["Company"] = relationship(back_populates="dishes")

class RecipeItem(Base):
    __tablename__ = "recipe_items"

    id: Mapped[int] = mapped_column(primary_key=True)
    dish_id: Mapped[int] = mapped_column(ForeignKey("dishes.id", ondelete="CASCADE"))
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id", ondelete="CASCADE"))
    quantity: Mapped[float] = mapped_column(Numeric(15, 3))  # количество товара на одно блюдо

    # relationships
    dish: Mapped["Dish"] = relationship(back_populates="recipe_items")
    product: Mapped["Product"] = relationship(back_populates="recipe_items")

class StockEntry(Base):
    __tablename__ = "stock_entries"

    id: Mapped[int] = mapped_column(primary_key=True)
    company_id: Mapped[int] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"))
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id", ondelete="CASCADE"))
    quantity: Mapped[float] = mapped_column(Numeric(15, 3))
    price_per_unit: Mapped[float] = mapped_column(Numeric(15, 2))  # цена за единицу в этом приходе
    date: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    description: Mapped[str | None] = mapped_column(String(200), nullable=True)
    created_by: Mapped[int] = mapped_column(ForeignKey("users.id"))

    # relationships
    company: Mapped["Company"] = relationship()
    product: Mapped["Product"] = relationship(back_populates="stock_entries")
    creator: Mapped["User"] = relationship()  

class StockWriteOff(Base):
    __tablename__ = "stock_write_offs"

    id: Mapped[int] = mapped_column(primary_key=True)
    company_id: Mapped[int] = mapped_column(ForeignKey("companies.id", ondelete="CASCADE"))
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id", ondelete="CASCADE"))
    quantity: Mapped[float] = mapped_column(Numeric(15, 3))
    reason: Mapped[str] = mapped_column(String(100))  # 'sale', 'spoilage', 'loss'
    dish_id: Mapped[int | None] = mapped_column(ForeignKey("dishes.id"), nullable=True)  # если списание связано с продажей блюда
    date: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    description: Mapped[str | None] = mapped_column(String(200), nullable=True)
    created_by: Mapped[int] = mapped_column(ForeignKey("users.id"))

    # relationships
    company: Mapped["Company"] = relationship()
    product: Mapped["Product"] = relationship(back_populates="write_offs")
    dish: Mapped["Dish"] = relationship()
    creator: Mapped["User"] = relationship()