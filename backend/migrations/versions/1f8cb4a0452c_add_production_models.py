"""add_production_models

Revision ID: 1f8cb4a0452c
Revises: eb3dabb4ee59
Create Date: 2026-06-12 20:30:32.638051

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '1f8cb4a0452c'
down_revision: Union[str, None] = 'eb3dabb4ee59'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Создаем ENUM типы (без IF NOT EXISTS, оборачиваем в DO блок)
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'productionorderstatus') THEN
                CREATE TYPE productionorderstatus AS ENUM ('PLANNED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED');
            END IF;
        END
        $$;
    """)
    
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'productiontransactiontype') THEN
                CREATE TYPE productiontransactiontype AS ENUM ('PRODUCTION', 'SALE');
            END IF;
        END
        $$;
    """)
    
    # Таблицы через op.create_table (без IF EXISTS)
    op.create_table('manufactured_products',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('company_id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('unit', sa.String(length=20), nullable=False, server_default='шт'),
        sa.Column('price', sa.Numeric(precision=15, scale=2), nullable=False, server_default='0'),
        sa.Column('recipe', sa.Text(), nullable=True),
        sa.Column('current_stock', sa.Numeric(precision=15, scale=3), nullable=False, server_default='0'),
        sa.Column('sort_order', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.text('now()')),
        sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.text('now()')),
        sa.Column('is_deleted', sa.Boolean(), nullable=False, server_default='false'),
        sa.ForeignKeyConstraint(['company_id'], ['companies.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    
    op.create_table('production_journal_entries',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('company_id', sa.Integer(), nullable=False),
        sa.Column('product_id', sa.Integer(), nullable=False),
        sa.Column('planned_quantity', sa.Numeric(precision=15, scale=3), nullable=False, server_default='0'),
        sa.Column('actual_quantity', sa.Numeric(precision=15, scale=3), nullable=False, server_default='0'),
        sa.Column('production_date', sa.DateTime(), nullable=False),
        sa.Column('shift', sa.String(length=20), nullable=False, server_default='day'),
        sa.Column('worker_name', sa.String(length=100), nullable=True),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('status', sa.Enum('PLANNED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', name='productionorderstatus'), nullable=False, server_default='COMPLETED'),
        sa.Column('created_by', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.text('now()')),
        sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.text('now()')),
        sa.ForeignKeyConstraint(['company_id'], ['companies.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['created_by'], ['users.id'], ),
        sa.ForeignKeyConstraint(['product_id'], ['manufactured_products.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    
    op.create_table('production_stock_transactions',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('company_id', sa.Integer(), nullable=False),
        sa.Column('product_id', sa.Integer(), nullable=False),
        sa.Column('type', sa.Enum('PRODUCTION', 'SALE', name='productiontransactiontype'), nullable=False),
        sa.Column('quantity', sa.Numeric(precision=15, scale=3), nullable=False),
        sa.Column('price_per_unit', sa.Numeric(precision=15, scale=2), nullable=True),
        sa.Column('journal_entry_id', sa.Integer(), nullable=True),
        sa.Column('transaction_id', sa.Integer(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.text('now()')),
        sa.Column('created_by', sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(['company_id'], ['companies.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['created_by'], ['users.id'], ),
        sa.ForeignKeyConstraint(['journal_entry_id'], ['production_journal_entries.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['product_id'], ['manufactured_products.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['transaction_id'], ['transactions.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id')
    )
    
    # Индексы
    op.create_index('idx_manufactured_products_company', 'manufactured_products', ['company_id'])
    op.create_index('idx_manufactured_products_deleted', 'manufactured_products', ['is_deleted'])
    op.create_index('idx_production_journal_date', 'production_journal_entries', ['production_date'])
    op.create_index('idx_production_journal_company', 'production_journal_entries', ['company_id'])
    op.create_index('idx_production_journal_product', 'production_journal_entries', ['product_id'])
    op.create_index('idx_production_stock_company', 'production_stock_transactions', ['company_id'])
    op.create_index('idx_production_stock_product', 'production_stock_transactions', ['product_id'])
    op.create_index('idx_production_stock_created', 'production_stock_transactions', ['created_at'])
    
    # Функция для updated_at
    op.execute("""
        CREATE OR REPLACE FUNCTION update_updated_at_column()
        RETURNS TRIGGER AS $$
        BEGIN
            NEW.updated_at = NOW();
            RETURN NEW;
        END;
        $$ language 'plpgsql';
    """)
    
    # Триггеры
    op.execute("DROP TRIGGER IF EXISTS update_manufactured_products_updated_at ON manufactured_products;")
    op.execute("""
        CREATE TRIGGER update_manufactured_products_updated_at
        BEFORE UPDATE ON manufactured_products
        FOR EACH ROW
        EXECUTE FUNCTION update_updated_at_column();
    """)
    
    op.execute("DROP TRIGGER IF EXISTS update_production_journal_entries_updated_at ON production_journal_entries;")
    op.execute("""
        CREATE TRIGGER update_production_journal_entries_updated_at
        BEFORE UPDATE ON production_journal_entries
        FOR EACH ROW
        EXECUTE FUNCTION update_updated_at_column();
    """)


def downgrade() -> None:
    op.execute("DROP TRIGGER IF EXISTS update_manufactured_products_updated_at ON manufactured_products;")
    op.execute("DROP TRIGGER IF EXISTS update_production_journal_entries_updated_at ON production_journal_entries;")
    
    op.drop_index('idx_production_stock_created', table_name='production_stock_transactions')
    op.drop_index('idx_production_stock_product', table_name='production_stock_transactions')
    op.drop_index('idx_production_stock_company', table_name='production_stock_transactions')
    op.drop_index('idx_production_journal_product', table_name='production_journal_entries')
    op.drop_index('idx_production_journal_company', table_name='production_journal_entries')
    op.drop_index('idx_production_journal_date', table_name='production_journal_entries')
    op.drop_index('idx_manufactured_products_deleted', table_name='manufactured_products')
    op.drop_index('idx_manufactured_products_company', table_name='manufactured_products')
    
    op.drop_table('production_stock_transactions')
    op.drop_table('production_journal_entries')
    op.drop_table('manufactured_products')
    
    op.execute("DROP TYPE IF EXISTS productiontransactiontype CASCADE;")
    op.execute("DROP TYPE IF EXISTS productionorderstatus CASCADE;")
    
    op.execute("DROP FUNCTION IF EXISTS update_updated_at_column CASCADE;")