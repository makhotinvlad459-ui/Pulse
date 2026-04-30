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

async def init_db():
    """Создаёт все таблицы, если их нет."""
    engine = get_engine()
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

async def init_permissions():
    """Заполняет таблицу permissions начальными правами."""
    from app.models import Permission
    from sqlalchemy import select

    permissions_list = [
        {"name": "view_operations", "description": "Просмотр операций"},
        {"name": "create_transaction", "description": "Создание операций"},
        {"name": "edit_transaction", "description": "Редактирование операций"},
        {"name": "view_showcase", "description": "Просмотр витрины"},
        {"name": "edit_showcase", "description": "Редактирование витрины (создание, изменение, удаление товаров/услуг)"},
        {"name": "sell_from_showcase", "description": "Продажа с витрины (оформление продажи)"},
        {"name": "view_chat", "description": "Просмотр чата компании"},
        {"name": "send_messages", "description": "Отправка сообщений в чат"},
        {"name": "view_tasks", "description": "Просмотр задач (включая принятие/выполнение)"},
        {"name": "create_task", "description": "Создание задач"},
        {"name": "edit_task", "description": "Изменение статуса задачи, удаление задач"},
        {"name": "manage_employees", "description": "Управление сотрудниками (добавление, удаление, сброс пароля)"},
        {"name": "manage_permissions", "description": "Управление правами других пользователей"},
        {"name": "view_accounts", "description": "Просмотр счетов и остатков"},
        {"name": "create_account", "description": "Создание новых счетов"},
        {"name": "manage_categories", "description": "Управление категориями (добавление, удаление)"},
        {"name": "view_reports", "description": "Просмотр отчётов (прибыль/убыток, динамика, продажи)"},
        {"name": "edit_company", "description": "Редактирование реквизитов компании"},
        {"name": "view_archive", "description": "Доступ к архиву (просмотр удалённых операций)"},
        {"name": "view_documents", "description": "Просмотр документов"},
        {"name": "create_documents", "description": "Создание документов"},
        {"name": "edit_documents", "description": "Редактирование документов"},
        {"name": "view_requests", "description": "Просмотр заявок"},
        {"name": "create_requests", "description": "Создание заявок"},
        {"name": "edit_requests", "description": "Редактирование заявок"},
        {"name": "view_products", "description": "Просмотр товаров на складе"},
        {"name": "create_product", "description": "Создание новых товаров"},
        {"name": "edit_product", "description": "Редактирование товаров"},
        {"name": "view_materials", "description": "Просмотр материалов"},
        {"name": "create_material", "description": "Создание материалов"},
        {"name": "edit_material", "description": "Редактирование материалов"},
    ]

    async with get_async_session()() as session:
        for perm_data in permissions_list:
            result = await session.execute(
                select(Permission).where(Permission.name == perm_data["name"])
            )
            if not result.scalar_one_or_none():
                session.add(Permission(**perm_data))
        await session.commit()