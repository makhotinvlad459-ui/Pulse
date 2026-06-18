"""add platform to payment_orders

Revision ID: fbef3e727cad
Revises: cd827023fa8c
Create Date: 2026-06-18 09:54:55.127664

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'fbef3e727cad'
down_revision: Union[str, None] = 'cd827023fa8c'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ============================================
    # БЕЗОПАСНАЯ МИГРАЦИЯ (без падения сервера)
    # ============================================
    
    # 1. Добавляем колонку с DEFAULT значением 'web'
    #    и разрешаем NULL (временный шаг)
    op.add_column(
        'payment_orders', 
        sa.Column('platform', sa.String(), nullable=True, server_default='web')
    )
    
    # 2. Обновляем существующие записи (если есть NULL)
    op.execute("UPDATE payment_orders SET platform = 'web' WHERE platform IS NULL")
    
    # 3. Делаем колонку NOT NULL после заполнения данных
    op.alter_column(
        'payment_orders', 
        'platform',
        nullable=False,
        server_default='web'  # сохраняем default для новых записей
    )


def downgrade() -> None:
    # ============================================
    # ОТКАТ (если понадобится)
    # ============================================
    op.drop_column('payment_orders', 'platform')