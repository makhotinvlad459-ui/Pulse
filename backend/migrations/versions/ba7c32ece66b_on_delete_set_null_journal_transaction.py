"""on_delete_set_null_journal_transaction

Revision ID: ba7c32ece66b
Revises: 10503e88f4cb
Create Date: 2026-06-04 15:16:47.319769

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = 'ba7c32ece66b'
down_revision: Union[str, None] = '10503e88f4cb'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    # Удаляем существующий внешний ключ (если есть)
    op.execute("ALTER TABLE journal_entries DROP CONSTRAINT IF EXISTS journal_entries_transaction_id_fkey")
    # Добавляем новый с ON DELETE SET NULL
    op.execute("""
        ALTER TABLE journal_entries ADD CONSTRAINT journal_entries_transaction_id_fkey 
        FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE SET NULL
    """)

def downgrade() -> None:
    # Удаляем новый ключ
    op.execute("ALTER TABLE journal_entries DROP CONSTRAINT IF EXISTS journal_entries_transaction_id_fkey")
    # Восстанавливаем старый (без ON DELETE)
    op.execute("""
        ALTER TABLE journal_entries ADD CONSTRAINT journal_entries_transaction_id_fkey 
        FOREIGN KEY (transaction_id) REFERENCES transactions(id)
    """)