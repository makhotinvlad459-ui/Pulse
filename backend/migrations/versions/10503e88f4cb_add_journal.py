"""add_journal

Revision ID: 10503e88f4cb
Revises: 67809c19b0ba
Create Date: 2026-06-03 13:41:57.232187

"""

revision = '10503e88f4cb'
down_revision = '67809c19b0ba'
branch_labels = None
depends_on = None

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

def upgrade():
    # Создаём ENUM, если он ещё не существует (без IF NOT EXISTS, т.к. старая версия PostgreSQL)
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'journalentrystatus') THEN
                CREATE TYPE journalentrystatus AS ENUM ('PLANNED', 'COMPLETED', 'CANCELLED');
            END IF;
        END
        $$;
    """)

    op.create_table('journal_entries',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('company_id', sa.Integer(), nullable=False),
        sa.Column('datetime_start', sa.DateTime(), nullable=False),
        sa.Column('datetime_end', sa.DateTime(), nullable=False),
        sa.Column('description', sa.String(length=500), nullable=True),
        sa.Column('counterparty', sa.String(length=200), nullable=True),
        sa.Column('status', postgresql.ENUM('PLANNED', 'COMPLETED', 'CANCELLED', name='journalentrystatus', create_type=False), nullable=False),
        sa.Column('transaction_id', sa.Integer(), nullable=True),
        sa.Column('showcase_item_id', sa.Integer(), nullable=True),
        sa.Column('quantity', sa.Integer(), nullable=False),
        sa.Column('total_amount', sa.Numeric(15, 2), nullable=False),
        sa.Column('created_by', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['company_id'], ['companies.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['created_by'], ['users.id'], ),
        sa.ForeignKeyConstraint(['showcase_item_id'], ['showcase_items.id'], ),
        sa.ForeignKeyConstraint(['transaction_id'], ['transactions.id'], ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('transaction_id')
    )
    op.create_index(op.f('ix_journal_entries_id'), 'journal_entries', ['id'], unique=False)

def downgrade():
    op.drop_index(op.f('ix_journal_entries_id'), table_name='journal_entries')
    op.drop_table('journal_entries')
    op.execute("DROP TYPE IF EXISTS journalentrystatus")