from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    # База данных
    DATABASE_URL: str = "postgresql+asyncpg://pulse_user:pulse_secret@db:5432/pulse"
    # JWT
    SECRET_KEY: str = "change_this_in_production_please"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    # SMTP (почта)
    SMTP_HOST: str = ""
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_FROM: str = ""
    # Другие настройки
    BACKEND_PORT: int = 8000
    DB_PORT: int = 5432
    DB_VOLUME: str = "postgres_data"

    class Config:
        env_file = ".env"
        extra = "ignore"  # игнорировать лишние переменные окружения

settings = Settings()