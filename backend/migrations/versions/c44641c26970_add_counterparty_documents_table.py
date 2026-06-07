"""add counterparty documents table

Revision ID: c44641c26970
Revises: 33e3bc8db8b8
Create Date: 2026-06-07 15:12:20.499139

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'c44641c26970'
down_revision: Union[str, None] = '33e3bc8db8b8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Создаём таблицу только если её нет
    op.execute("""
        CREATE TABLE IF NOT EXISTS counterparty_documents (
            id SERIAL PRIMARY KEY,
            counterparty_id INTEGER NOT NULL,
            file_url VARCHAR(500) NOT NULL,
            uploaded_by INTEGER NOT NULL,
            uploaded_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
            file_name VARCHAR(255) NOT NULL,
            description VARCHAR(500)
        );
    """)

    # 2. Добавляем внешние ключи, если они ещё не существуют
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint WHERE conname = 'counterparty_documents_counterparty_id_fkey'
            ) THEN
                ALTER TABLE counterparty_documents
                ADD CONSTRAINT counterparty_documents_counterparty_id_fkey
                FOREIGN KEY (counterparty_id) REFERENCES counterparties(id) ON DELETE CASCADE;
            END IF;
        END
        $$;
    """)

    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint WHERE conname = 'counterparty_documents_uploaded_by_fkey'
            ) THEN
                ALTER TABLE counterparty_documents
                ADD CONSTRAINT counterparty_documents_uploaded_by_fkey
                FOREIGN KEY (uploaded_by) REFERENCES users(id);
            END IF;
        END
        $$;
    """)


def downgrade() -> None:
    # Удаляем только если таблица существует
    op.execute("DROP TABLE IF EXISTS counterparty_documents CASCADE;")