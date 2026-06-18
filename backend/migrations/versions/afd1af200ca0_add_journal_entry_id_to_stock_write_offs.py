"""add journal_entry_id to stock_write_offs

Revision ID: afd1af200ca0
Revises: 8b4f67046363
Create Date: 2026-06-18 20:59:54.736641

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'afd1af200ca0'
down_revision: Union[str, None] = '8b4f67046363'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Добавляем колонку с NULL (безопасно)
    op.add_column('stock_write_offs', sa.Column('journal_entry_id', sa.Integer(), nullable=True))
    
    # 2. Создаём внешний ключ с явным именем и каскадным удалением
    op.create_foreign_key(
        'fk_stock_write_offs_journal_entry_id',           # имя ограничения
        'stock_write_offs',                               # таблица
        'production_journal_entries',                     # ссылается на таблицу
        ['journal_entry_id'],                             # колонка в текущей таблице
        ['id'],                                           # колонка в целевой таблице
        ondelete='CASCADE'                                # при удалении записи журнала удалять списания
    )


def downgrade() -> None:
    # 1. Удаляем внешний ключ по имени
    op.drop_constraint('fk_stock_write_offs_journal_entry_id', 'stock_write_offs', type_='foreignkey')
    
    # 2. Удаляем колонку
    op.drop_column('stock_write_offs', 'journal_entry_id')