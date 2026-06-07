"""add journal attachments table

Revision ID: bf086206f083
Revises: 934889ae4e44
Create Date: 2026-06-07 07:13:06.556099

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'bf086206f083'
down_revision: Union[str, None] = '934889ae4e44'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Создаём таблицу journal_attachments, если её нет
    op.execute("""
        CREATE TABLE IF NOT EXISTS journal_attachments (
            id SERIAL PRIMARY KEY,
            journal_entry_id INTEGER NOT NULL,
            file_url VARCHAR(500) NOT NULL,
            uploaded_by INTEGER NOT NULL,
            uploaded_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
            file_name VARCHAR(255)
        );
    """)

    # 2. Добавляем внешний ключ, если не существует
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint WHERE conname = 'journal_attachments_journal_entry_id_fkey'
            ) THEN
                ALTER TABLE journal_attachments
                ADD CONSTRAINT journal_attachments_journal_entry_id_fkey
                FOREIGN KEY (journal_entry_id) REFERENCES journal_entries(id) ON DELETE CASCADE;
            END IF;
        END
        $$;
    """)

    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint WHERE conname = 'journal_attachments_uploaded_by_fkey'
            ) THEN
                ALTER TABLE journal_attachments
                ADD CONSTRAINT journal_attachments_uploaded_by_fkey
                FOREIGN KEY (uploaded_by) REFERENCES users(id);
            END IF;
        END
        $$;
    """)

    # 3. Исправляем внешний ключ в journal_entries, если нужно (меняем поведение при удалении)
    # Проверяем существующий FK и пересоздаём с нужным ON DELETE (без SET NULL)
    op.execute("""
        DO $$
        DECLARE
            con_name text;
        BEGIN
            SELECT conname INTO con_name
            FROM pg_constraint
            WHERE conrelid = 'journal_entries'::regclass
              AND confrelid = 'transactions'::regclass
              AND contype = 'f';
            IF con_name IS NOT NULL THEN
                EXECUTE format('ALTER TABLE journal_entries DROP CONSTRAINT %I', con_name);
            END IF;
        END
        $$;
    """)
    op.execute("""
        ALTER TABLE journal_entries
        ADD CONSTRAINT journal_entries_transaction_id_fkey
        FOREIGN KEY (transaction_id) REFERENCES transactions(id);
    """)

    # 4. Удаляем старый индекс, если существует (он обычно не нужен, так как PRIMARY KEY даёт индекс)
    op.execute("DROP INDEX IF EXISTS ix_journal_entries_id;")


def downgrade() -> None:
    # 1. Удаляем таблицу journal_attachments, если она существует
    op.execute("DROP TABLE IF EXISTS journal_attachments;")

    # 2. Восстанавливаем старый внешний ключ journal_entries (с ON DELETE SET NULL)
    op.execute("""
        DO $$
        DECLARE
            con_name text;
        BEGIN
            SELECT conname INTO con_name
            FROM pg_constraint
            WHERE conrelid = 'journal_entries'::regclass
              AND confrelid = 'transactions'::regclass
              AND contype = 'f';
            IF con_name IS NOT NULL THEN
                EXECUTE format('ALTER TABLE journal_entries DROP CONSTRAINT %I', con_name);
            END IF;
        END
        $$;
    """)
    op.execute("""
        ALTER TABLE journal_entries
        ADD CONSTRAINT journal_entries_transaction_id_fkey
        FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE SET NULL;
    """)

    # 3. Восстанавливаем индекс, если он был удалён
    op.execute("CREATE INDEX IF NOT EXISTS ix_journal_entries_id ON journal_entries(id);")