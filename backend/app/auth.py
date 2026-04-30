from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from jose import jwt
from passlib.context import CryptContext
from pydantic import BaseModel

from app.database import get_db
from app.models import User, UserRole
from app.config import settings
from app.deps import get_current_user

router = APIRouter(prefix="/auth", tags=["auth"])

pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

class RegisterRequest(BaseModel):
    email: str
    phone: str
    full_name: str
    password: str

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)

@router.post("/register")
async def register(
    register_data: RegisterRequest,
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(User).where((User.email == register_data.email) | (User.phone == register_data.phone))
    )
    existing_user = result.scalar_one_or_none()
    if existing_user:
        raise HTTPException(status_code=400, detail="User with this email or phone already exists")

    subscription_until = datetime.utcnow() + timedelta(days=30)
    new_user = User(
        email=register_data.email,
        phone=register_data.phone,
        full_name=register_data.full_name,
        password_hash=get_password_hash(register_data.password),
        role=UserRole.FOUNDER,
        subscription_until=subscription_until,
        soft_delete_retention_days=15,
        is_active=True,
    )
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)

    access_token = create_access_token(data={"sub": str(new_user.id), "role": new_user.role.value})
    return {"access_token": access_token, "token_type": "bearer"}

@router.post("/login")
async def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(User).where((User.email == form_data.username) | (User.phone == form_data.username))
    )
    user = result.scalar_one_or_none()
    if not user or not verify_password(form_data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    # Проверка активности
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Account is deactivated")

    if user.role == UserRole.FOUNDER and user.subscription_until and user.subscription_until < datetime.utcnow():
        raise HTTPException(status_code=403, detail="Subscription expired")

    user.last_login = datetime.utcnow()
    await db.commit()

    access_token = create_access_token(data={"sub": str(user.id), "role": user.role.value})
    return {"access_token": access_token, "token_type": "bearer"}

@router.get("/me")
async def get_current_user_info(
    current_user: User = Depends(get_current_user),
):
    return {
        "id": current_user.id,
        "email": current_user.email,
        "phone": current_user.phone,
        "full_name": current_user.full_name,
        "role": current_user.role.value,
        "subscription_until": current_user.subscription_until.isoformat() if current_user.subscription_until else None,
        "is_active": current_user.is_active,
    }

@router.post("/admin/register-founder")
async def admin_register_founder(
    email: str,
    phone: str,
    full_name: str,
    password: str,
    subscription_days: int = 30,
    permanent: bool = False,
    db: AsyncSession = Depends(get_db),
    current_admin: User = Depends(get_current_user)
):
    if current_admin.role != UserRole.SUPERADMIN:
        raise HTTPException(status_code=403, detail="Only superadmin can register founders")
    
    result = await db.execute(
        select(User).where((User.email == email) | (User.phone == phone))
    )
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="User already exists")
    
    if permanent:
        subscription_until = None
    else:
        subscription_until = datetime.utcnow() + timedelta(days=subscription_days)
    
    new_user = User(
        email=email,
        phone=phone,
        full_name=full_name,
        password_hash=get_password_hash(password),
        role=UserRole.FOUNDER,
        subscription_until=subscription_until,
        soft_delete_retention_days=15,
        is_active=True,
    )
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)
    
    return {
        "id": new_user.id,
        "email": new_user.email,
        "phone": new_user.phone,
        "full_name": new_user.full_name,
        "subscription_until": subscription_until.isoformat() if subscription_until else None
    }