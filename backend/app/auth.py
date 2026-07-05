from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete, or_
from jose import jwt, JWTError
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
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")

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

    @validator('email', pre=True)
    def email_to_lower(cls, v):
        if isinstance(v, str):
            return v.lower().strip()
        return v

    @validator('phone', pre=True)
    def empty_phone_to_none(cls, v):
        if v == '':
            return None
        if isinstance(v, str):
            return v.strip()
        return v

    @validator('password')
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters')
        return v

class ForgotPasswordRequest(BaseModel):
    email: EmailStr

    @validator('email', pre=True)
    def email_to_lower(cls, v):
        if isinstance(v, str):
            return v.lower().strip()
        return v

class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str

    @validator('new_password')
    def validate_new_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters')
        return v

class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str

class RefreshRequest(BaseModel):
    refresh_token: str

class DeleteAccountRequest(BaseModel):
    password: str

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

def create_refresh_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)

# ---------- Регистрация ----------
@router.post("/register")
async def register(register_data: RegisterRequest, db: AsyncSession = Depends(get_db)):
    # Строгая проверка: ищем пользователей с такой же почтой ИЛИ таким же телефоном
    query_conditions = [User.email == register_data.email]
    if register_data.phone:
        query_conditions.append(User.phone == register_data.phone)
        
    result = await db.execute(select(User).where(or_(*query_conditions)))
    existing_user = result.scalar_one_or_none()
    
    if existing_user:
        if existing_user.email == register_data.email:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "User with this email already exists")
        if register_data.phone and existing_user.phone == register_data.phone:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "User with this phone number already exists")

    hashed = get_password_hash(register_data.password)
    
    # Новый пользователь НЕ получает подписку автоматически
    new_user = User(
        email=register_data.email,
        phone=register_data.phone,
        full_name=register_data.full_name,
        password_hash=hashed,
        role=UserRole.FOUNDER,
        subscription_until=None,  # ← Без подписки при регистрации
        soft_delete_retention_days=15,
        is_active=True
    )
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)
    
    token = create_access_token(data={"sub": str(new_user.id), "role": new_user.role.value})
    return {"access_token": token, "token_type": "bearer"}

# ---------- Логин (исправлен) ----------
@router.post("/login")
async def login(form_data: OAuth2PasswordRequestForm = Depends(), db: AsyncSession = Depends(get_db)):
    username_clean = form_data.username.lower().strip()
    user = await db.execute(
        select(User).where(
            or_(
                User.email == username_clean,
                User.phone == form_data.username.strip()
            )
        )
    )
    user = user.scalar_one_or_none()
    
    # Проверка credentials
    if not user or not verify_password(form_data.password, user.password_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid credentials")
    
    # Проверка активности аккаунта
    if not user.is_active:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Account deactivated")
    
    # ✅ УБРАЛИ ПРОВЕРКУ ПОДПИСКИ!
    # Теперь пользователь может войти даже с истекшей подпиской,
    # чтобы иметь возможность её оплатить.
    # Ограничения будут работать через /subscription/status и бизнес-эндпоинты.
        
    user.last_login = datetime.utcnow()
    
    # Генерируем токены
    access_token = create_access_token(data={"sub": str(user.id), "role": user.role.value})
    refresh_token = create_refresh_token(data={"sub": str(user.id)})
    user.refresh_token = refresh_token
    await db.commit()
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer"
    }

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
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, "Email service not configured")
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

    frontend_url = settings.FRONTEND_URL if hasattr(settings, 'FRONTEND_URL') else "http://localhost:4200"
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
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid or expired token")
    user = await db.get(User, reset_token.user_id)
    if not user:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "User not found")
    user.password_hash = get_password_hash(data.new_password)
    await db.delete(reset_token)
    await db.commit()
    return {"detail": "Password has been reset"}

@router.post("/change-password")
async def change_password(
    data: ChangePasswordRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Проверяем старый пароль
    if not verify_password(data.old_password, current_user.password_hash):
        raise HTTPException(status_code=400, detail="Old password is incorrect")
    
    # Проверяем новый пароль (длина)
    if len(data.new_password) < 8:
        raise HTTPException(status_code=400, detail="Password must be at least 8 characters")
    
    # Хешируем и сохраняем
    current_user.password_hash = get_password_hash(data.new_password)
    await db.commit()
    
    return {"detail": "Password changed successfully"}

@router.post("/update-language")
async def update_language(
    data: dict, 
    db: AsyncSession = Depends(get_db), 
    current_user: User = Depends(get_current_user)
):
    new_lang = data.get("language")
    current_user.language = new_lang
    await db.commit()
    return {"message": "Language updated"}

@router.post("/refresh")
async def refresh_token(
    req: RefreshRequest,
    db: AsyncSession = Depends(get_db)
):
    try:
        payload = jwt.decode(req.refresh_token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id = payload.get("sub")
        if user_id is None:
            raise HTTPException(status_code=401, detail="Invalid refresh token")
        result = await db.execute(select(User).where(User.id == int(user_id)))
        user = result.scalar_one_or_none()
        if not user or user.refresh_token != req.refresh_token:
            raise HTTPException(status_code=401, detail="Invalid refresh token")
        new_access = create_access_token(data={"sub": str(user.id), "role": user.role.value})
        return {"access_token": new_access}
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    
@router.post("/logout")
async def logout(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    current_user.refresh_token = None
    await db.commit()
    return {"detail": "Logged out"}

# ---------- Удаление аккаунта ----------
@router.delete("/me", status_code=200)
async def delete_my_account(
    data: DeleteAccountRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Проверка пароля
    if not verify_password(data.password, current_user.password_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid password")
    
    # Анонимизация персональных данных
    current_user.email = f"deleted_{current_user.id}@anonymized.local"
    current_user.phone = None
    current_user.full_name = "Deleted User"
    current_user.is_active = False
    current_user.refresh_token = None
    current_user.deleted_at = datetime.utcnow()
    
    await db.commit()
    
    return {"detail": "Account permanently deleted. Your personal data has been removed."}