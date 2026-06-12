"""add_production_models

Revision ID: 1f8cb4a0452c
Revises: eb3dabb4ee59
Create Date: 2026-06-12 20:30:32.638051

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import ENUM

# revision identifiers, used by Alembic.
revision: str = '1f8cb4a0452c'
down_revision: Union[str, None] = 'eb3dabb4ee59'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Используем существующие ENUM типы или создаем если их нет
    productionorderstatus = ENUM('PLANNED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', name='productionorderstatus', create_type=False)
    productiontransactiontype = ENUM('PRODUCTION', 'SALE', name='productiontransactiontype', create_type=False)
    
    # Создаем ENUM типы только если они не существуют
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
    
    # Создаем таблицы с проверкой существования
    op.execute("""
        CREATE TABLE IF NOT EXISTS manufactured_products (
            id SERIAL PRIMARY KEY,
            company_id INTEGER NOT NULL,
            name VARCHAR(100) NOT NULL,
            unit VARCHAR(20) NOT NULL DEFAULT 'шт',
            price NUMERIC(15, 2) NOT NULL DEFAULT 0,
            recipe TEXT,
            current_stock NUMERIC(15, 3) NOT NULL DEFAULT 0,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
            is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
            CONSTRAINT fk_manufactured_products_company FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE
        );
    """)
    
    op.execute("""
        CREATE TABLE IF NOT EXISTS production_journal_entries (
            id SERIAL PRIMARY KEY,
            company_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            planned_quantity NUMERIC(15, 3) NOT NULL DEFAULT 0,
            actual_quantity NUMERIC(15, 3) NOT NULL DEFAULT 0,
            production_date TIMESTAMP NOT NULL,
            shift VARCHAR(20) NOT NULL DEFAULT 'day',
            worker_name VARCHAR(100),
            notes TEXT,
            status productionorderstatus NOT NULL DEFAULT 'COMPLETED',
            created_by INTEGER NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
            CONSTRAINT fk_production_journal_company FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE,
            CONSTRAINT fk_production_journal_product FOREIGN KEY (product_id) REFERENCES manufactured_products(id) ON DELETE CASCADE,
            CONSTRAINT fk_production_journal_creator FOREIGN KEY (created_by) REFERENCES users(id)
        );
    """)
    
    op.execute("""
        CREATE TABLE IF NOT EXISTS production_stock_transactions (
            id SERIAL PRIMARY KEY,
            company_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            type productiontransactiontype NOT NULL,
            quantity NUMERIC(15, 3) NOT NULL,
            price_per_unit NUMERIC(15, 2),
            journal_entry_id INTEGER,
            transaction_id INTEGER,
            created_at TIMESTAMP NOT NULL DEFAULT NOW(),
            created_by INTEGER NOT NULL,
            CONSTRAINT fk_production_stock_company FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE,
            CONSTRAINT fk_production_stock_product FOREIGN KEY (product_id) REFERENCES manufactured_products(id) ON DELETE CASCADE,
            CONSTRAINT fk_production_stock_journal FOREIGN KEY (journal_entry_id) REFERENCES production_journal_entries(id) ON DELETE SET NULL,
            CONSTRAINT fk_production_stock_transaction FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE SET NULL,
            CONSTRAINT fk_production_stock_creator FOREIGN KEY (created_by) REFERENCES users(id)
        );
    """)
    
    # Создаем индексы (проверяем существование)
    op.execute("CREATE INDEX IF NOT EXISTS idx_manufactured_products_company ON manufactured_products(company_id);")
    op.execute("CREATE INDEX IF NOT EXISTS idx_manufactured_products_deleted ON manufactured_products(is_deleted);")
    op.execute("CREATE INDEX IF NOT EXISTS idx_production_journal_date ON production_journal_entries(production_date);")
    op.execute("CREATE INDEX IF NOT EXISTS idx_production_journal_company ON production_journal_entries(company_id);")
    op.execute("CREATE INDEX IF NOT EXISTS idx_production_journal_product ON production_journal_entries(product_id);")
    op.execute("CREATE INDEX IF NOT EXISTS idx_production_stock_company ON production_stock_transactions(company_id);")
    op.execute("CREATE INDEX IF NOT EXISTS idx_production_stock_product ON production_stock_transactions(product_id);")
    op.execute("CREATE INDEX IF NOT EXISTS idx_production_stock_created ON production_stock_transactions(created_at);")
    
    # Триггер для updated_at (только если функция еще не существует)
    op.execute("""
        CREATE OR REPLACE FUNCTION update_updated_at_column()
        RETURNS TRIGGER AS $$
        BEGIN
            NEW.updated_at = NOW();
            RETURN NEW;
        END;
        $$ language 'plpgsql';
    """)
    
    op.execute("""
        DROP TRIGGER IF EXISTS update_manufactured_products_updated_at ON manufactured_products;
        CREATE TRIGGER update_manufactured_products_updated_at
            BEFORE UPDATE ON manufactured_products
            FOR EACH ROW
            EXECUTE FUNCTION update_updated_at_column();
    """)
    
    op.execute("""
        DROP TRIGGER IF EXISTS update_production_journal_entries_updated_at ON production_journal_entries;
        CREATE TRIGGER update_production_journal_entries_updated_at
            BEFORE UPDATE ON production_journal_entries
            FOR EACH ROW
            EXECUTE FUNCTION update_updated_at_column();
    """)


def downgrade() -> None:
    # Удаляем триггеры
    op.execute("DROP TRIGGER IF EXISTS update_manufactured_products_updated_at ON manufactured_products;")
    op.execute("DROP TRIGGER IF EXISTS update_production_journal_entries_updated_at ON production_journal_entries;")
    
    # Удаляем индексы
    op.execute("DROP INDEX IF EXISTS idx_production_stock_created;")
    op.execute("DROP INDEX IF EXISTS idx_production_stock_product;")
    op.execute("DROP INDEX IF EXISTS idx_production_stock_company;")
    op.execute("DROP INDEX IF EXISTS idx_production_journal_product;")
    op.execute("DROP INDEX IF EXISTS idx_production_journal_company;")
    op.execute("DROP INDEX IF EXISTS idx_production_journal_date;")
    op.execute("DROP INDEX IF EXISTS idx_manufactured_products_deleted;")
    op.execute("DROP INDEX IF EXISTS idx_manufactured_products_company;")
    
    # Удаляем таблицы
    op.execute("DROP TABLE IF EXISTS production_stock_transactions CASCADE;")
    op.execute("DROP TABLE IF EXISTS production_journal_entries CASCADE;")
    op.execute("DROP TABLE IF EXISTS manufactured_products CASCADE;")
    
    # Удаляем ENUM типы (только если они есть)
    op.execute("DROP TYPE IF EXISTS productiontransactiontype CASCADE;")
    op.execute("DROP TYPE IF EXISTS productionorderstatus CASCADE;")
    
    # Удаляем функцию
    op.execute("DROP FUNCTION IF EXISTS update_updated_at_column CASCADE;")