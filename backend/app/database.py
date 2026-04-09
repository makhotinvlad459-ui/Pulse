from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import declarative_base
from app.config import settings

Base = declarative_base()

_engine = None

def get_engine():
    global _engine
    if _engine is None:
        _engine = create_async_engine(settings.DATABASE_URL, echo=True)
    return _engine

def get_async_session():
    engine = get_engine()
    return async_sessionmaker(engine, expire_on_commit=False)

async def get_db() -> AsyncSession:
    async with get_async_session()() as session:
        yield session