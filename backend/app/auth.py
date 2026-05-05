from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from jose import jwt
from passlib.context import CryptContext
from pydantic import BaseModel, EmailStr, validator
import secrets
from fastapi_mail import FastMail, ConnectionConfig, MessageSchema, MessageType

from app.database import get_db
from app.models import User, UserRole, PasswordResetToken
from app.config import settings
from app.deps import get_current_user

router = APIRouter(prefix="/auth", tags=["auth"])

pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

# ---------- Настройка почты ----------
if settings.SMTP_USER and settings.SMTP_FROM:
    conf = ConnectionConfig(
        MAIL_USERNAME=settings.SMTP_USER,
        MAIL_PASSWORD=settings.SMTP_PASSWORD,
        MAIL_FROM=settings.SMTP_FROM,
        MAIL_PORT=settings.SMTP_PORT,
        MAIL_SERVER=settings.SMTP_HOST,
        MAIL_FROM_NAME="Pulse",
        MAIL_STARTTLS=True,
        MAIL_SSL_TLS=False,
        USE_CREDENTIALS=True,
        VALIDATE_CERTS=True
    )
else:
    conf = None

# ---------- Схемы ----------
class RegisterRequest(BaseModel):
    email: EmailStr
    phone: str | None = None
    full_name: str
    password: str

    @validator('password')
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters')
        return v

class ForgotPasswordRequest(BaseModel):
    email: EmailStr

class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str

    @validator('new_password')
    def validate_new_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters')
        return v

# ---------- Утилиты ----------
def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)

# ---------- Регистрация ----------
@router.post("/register")
async def register(register_data: RegisterRequest, db: AsyncSession = Depends(get_db)):
    conditions = [User.email == register_data.email]
    if register_data.phone:
        conditions.append(User.phone == register_data.phone)
    result = await db.execute(select(User).where(*conditions))
    if result.scalar_one_or_none():
        raise HTTPException(400, "User already exists")
    hashed = get_password_hash(register_data.password)
    subscription_until = datetime.utcnow() + timedelta(days=30)
    new_user = User(
        email=register_data.email,
        phone=register_data.phone,
        full_name=register_data.full_name,
        password_hash=hashed,
        role=UserRole.FOUNDER,
        subscription_until=subscription_until,
        soft_delete_retention_days=15,
        is_active=True
    )
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)
    token = create_access_token(data={"sub": str(new_user.id), "role": new_user.role.value})
    return {"access_token": token, "token_type": "bearer"}

# ---------- Логин ----------
@router.post("/login")
async def login(form_data: OAuth2PasswordRequestForm = Depends(), db: AsyncSession = Depends(get_db)):
    user = await db.execute(select(User).where((User.email == form_data.username) | (User.phone == form_data.username)))
    user = user.scalar_one_or_none()
    if not user or not verify_password(form_data.password, user.password_hash):
        raise HTTPException(401, "Invalid credentials")
    if not user.is_active:
        raise HTTPException(403, "Account deactivated")
    if user.role == UserRole.FOUNDER and user.subscription_until and user.subscription_until < datetime.utcnow():
        raise HTTPException(403, "Subscription expired")
    user.last_login = datetime.utcnow()
    await db.commit()
    token = create_access_token(data={"sub": str(user.id), "role": user.role.value})
    return {"access_token": token, "token_type": "bearer"}

# ---------- Текущий пользователь ----------
@router.get("/me")
async def get_current_user_info(current_user: User = Depends(get_current_user)):
    return {
        "id": current_user.id,
        "email": current_user.email,
        "phone": current_user.phone,
        "full_name": current_user.full_name,
        "role": current_user.role.value,
        "subscription_until": current_user.subscription_until.isoformat() if current_user.subscription_until else None,
        "is_active": current_user.is_active,
    }

# ---------- Восстановление пароля ----------
@router.post("/forgot-password")
async def forgot_password(data: ForgotPasswordRequest, db: AsyncSession = Depends(get_db)):
    if not conf:
        raise HTTPException(500, "Email service not configured")
    user = await db.execute(select(User).where(User.email == data.email))
    user = user.scalar_one_or_none()
    if not user:
        return {"detail": "If that email exists, a reset link has been sent"}

    await db.execute(delete(PasswordResetToken).where(PasswordResetToken.user_id == user.id))

    token = secrets.token_urlsafe(32)
    expires_at = datetime.utcnow() + timedelta(hours=1)
    reset_token = PasswordResetToken(user_id=user.id, token=token, expires_at=expires_at)
    db.add(reset_token)
    await db.commit()

    frontend_url = "http://localhost:4200"  # замените на адрес вашего фронтенда
    reset_link = f"{frontend_url}/reset-password?token={token}"

    message = MessageSchema(
        subject="Восстановление пароля Pulse",
        recipients=[user.email],
        body=f"""
        <h2>Восстановление пароля</h2>
        <p>Перейдите по ссылке, чтобы сбросить пароль:</p>
        <a href="{reset_link}">{reset_link}</a>
        <p>Ссылка действительна 1 час.</p>
        """,
        subtype=MessageType.html
    )
    fm = FastMail(conf)
    await fm.send_message(message)

    return {"detail": "If that email exists, a reset link has been sent"}

@router.post("/reset-password")
async def reset_password(data: ResetPasswordRequest, db: AsyncSession = Depends(get_db)):
    reset_token = await db.execute(select(PasswordResetToken).where(PasswordResetToken.token == data.token))
    reset_token = reset_token.scalar_one_or_none()
    if not reset_token or reset_token.expires_at < datetime.utcnow():
        raise HTTPException(400, "Invalid or expired token")
    user = await db.get(User, reset_token.user_id)
    if not user:
        raise HTTPException(404, "User not found")
    user.password_hash = get_password_hash(data.new_password)
    await db.delete(reset_token)
    await db.commit()
    return {"detail": "Password has been reset"}
