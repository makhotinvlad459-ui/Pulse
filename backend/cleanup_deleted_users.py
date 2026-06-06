import asyncio
from datetime import datetime, timedelta
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy import select, delete
from app.config import settings
from app.models import User, Company

async def cleanup():
    engine = create_async_engine(settings.DATABASE_URL)
    async_session = sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)
    async with async_session() as db:
        cutoff = datetime.utcnow() - timedelta(days=90)
        # Пользователи, удалённые более 90 дней назад
        users = await db.execute(
            select(User).where(User.deleted_at < cutoff, User.is_active == False)
        )
        for user in users.scalars():
            # Удаляем компании, где он учредитель (и нет других членов)
            companies = await db.execute(
                select(Company).where(Company.founder_id == user.id)
            )
            for company in companies.scalars():
                # Проверьте, есть ли у компании другие члены (кроме удалённого учредителя)
                # Если нет – удаляем компанию
                await db.delete(company)
            await db.delete(user)
        await db.commit()
        print(f"Cleaned up {users.scalars().count()} users")

if __name__ == "__main__":
    asyncio.run(cleanup())