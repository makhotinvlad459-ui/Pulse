import sys
from pathlib import Path
from logging.config import fileConfig

from sqlalchemy import engine_from_config, pool
from alembic import context

sys.path.append(str(Path(__file__).parent.parent))

from app.database import Base
# Явно импортируем все модели, чтобы они зарегистрировались в Base.metadata
from app.models import User, Company, CompanyMember, Account, Category, Transaction

from app.config import settings

config = context.config
sync_url = settings.DATABASE_URL.replace('+asyncpg', '')
config.set_main_option('sqlalchemy.url', sync_url)

fileConfig(config.config_file_name)

target_metadata = Base.metadata

def run_migrations_offline():
    context.configure(url=sync_url, target_metadata=target_metadata, literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()

def run_migrations_online():
    connectable = engine_from_config(
        config.get_section(config.config_ini_section),
        prefix='sqlalchemy.',
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()

if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()