"""add_items_to_journal_entries

Revision ID: 934889ae4e44
Revises: ba7c32ece66b
Create Date: 2026-06-04 17:39:00.688715

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = '934889ae4e44'
down_revision: Union[str, None] = 'ba7c32ece66b'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('journal_entries', sa.Column('items', postgresql.JSONB(astext_type=sa.Text()), nullable=True))


def downgrade() -> None:
   op.drop_column('journal_entries', 'items')
