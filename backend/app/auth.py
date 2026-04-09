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

router = APIRouter(prefix="/auth", tags=["auth"])

pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

# Pydantic-модель для регистрации
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
    # Проверяем, не существует ли пользователь
    result = await db.execute(
        select(User).where((User.email == register_data.email) | (User.phone == register_data.phone))
    )
    existing_user = result.scalar_one_or_none()
    if existing_user:
        raise HTTPException(status_code=400, detail="User with this email or phone already exists")

    # Эмуляция покупки подписки – устанавливаем subscription_until на 30 дней вперёд
    subscription_until = datetime.utcnow() + timedelta(days=30)

    new_user = User(
        email=register_data.email,
        phone=register_data.phone,
        full_name=register_data.full_name,
        password_hash=get_password_hash(register_data.password),
        role=UserRole.FOUNDER,
        subscription_until=subscription_until,
        soft_delete_retention_days=15,
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

    if user.role == UserRole.FOUNDER and user.subscription_until and user.subscription_until < datetime.utcnow():
        raise HTTPException(status_code=403, detail="Subscription expired")

    # Обновляем время последнего входа
    user.last_login = datetime.utcnow()
    await db.commit()

    access_token = create_access_token(data={"sub": str(user.id), "role": user.role.value})
    return {"access_token": access_token, "token_type": "bearer"}