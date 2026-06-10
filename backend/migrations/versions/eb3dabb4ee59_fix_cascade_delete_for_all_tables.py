"""fix_cascade_delete_for_all_tables

Revision ID: eb3dabb4ee59
Revises: c44641c26970
Create Date: 2026-06-10 19:51:46.655195

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'eb3dabb4ee59'
down_revision: Union[str, None] = 'c44641c26970'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    # 1. order_items_product_id_fkey
    op.drop_constraint('order_items_product_id_fkey', 'order_items', type_='foreignkey')
    op.create_foreign_key(
        'order_items_product_id_fkey', 'order_items', 'products',
        ['product_id'], ['id'], ondelete='CASCADE'
    )
    
    # 2. showcase_items_category_id_fkey
    op.drop_constraint('showcase_items_category_id_fkey', 'showcase_items', type_='foreignkey')
    op.create_foreign_key(
        'showcase_items_category_id_fkey', 'showcase_items', 'categories',
        ['category_id'], ['id'], ondelete='CASCADE'
    )
    
    # 3. transactions_account_id_fkey
    op.drop_constraint('transactions_account_id_fkey', 'transactions', type_='foreignkey')
    op.create_foreign_key(
        'transactions_account_id_fkey', 'transactions', 'accounts',
        ['account_id'], ['id'], ondelete='CASCADE'
    )
    
    # 4. transactions_category_id_fkey
    op.drop_constraint('transactions_category_id_fkey', 'transactions', type_='foreignkey')
    op.create_foreign_key(
        'transactions_category_id_fkey', 'transactions', 'categories',
        ['category_id'], ['id'], ondelete='SET NULL'
    )
    
    # 5. transactions_showcase_item_id_fkey
    op.drop_constraint('transactions_showcase_item_id_fkey', 'transactions', type_='foreignkey')
    op.create_foreign_key(
        'transactions_showcase_item_id_fkey', 'transactions', 'showcase_items',
        ['showcase_item_id'], ['id'], ondelete='SET NULL'
    )
    
    # 6. transactions_transfer_to_account_id_fkey
    op.drop_constraint('transactions_transfer_to_account_id_fkey', 'transactions', type_='foreignkey')
    op.create_foreign_key(
        'transactions_transfer_to_account_id_fkey', 'transactions', 'accounts',
        ['transfer_to_account_id'], ['id'], ondelete='CASCADE'
    )
    
    # 7. order_payments_transaction_id_fkey
    op.drop_constraint('order_payments_transaction_id_fkey', 'order_payments', type_='foreignkey')
    op.create_foreign_key(
        'order_payments_transaction_id_fkey', 'order_payments', 'transactions',
        ['transaction_id'], ['id'], ondelete='CASCADE'
    )
    
    # 8. transaction_items_product_id_fkey
    op.drop_constraint('transaction_items_product_id_fkey', 'transaction_items', type_='foreignkey')
    op.create_foreign_key(
        'transaction_items_product_id_fkey', 'transaction_items', 'products',
        ['product_id'], ['id'], ondelete='CASCADE'
    )

def downgrade():
    # Возвращаем как было (NO ACTION)
    op.drop_constraint('order_items_product_id_fkey', 'order_items', type_='foreignkey')
    op.create_foreign_key('order_items_product_id_fkey', 'order_items', 'products', ['product_id'], ['id'])
    
    op.drop_constraint('showcase_items_category_id_fkey', 'showcase_items', type_='foreignkey')
    op.create_foreign_key('showcase_items_category_id_fkey', 'showcase_items', 'categories', ['category_id'], ['id'])
    
    op.drop_constraint('transactions_account_id_fkey', 'transactions', type_='foreignkey')
    op.create_foreign_key('transactions_account_id_fkey', 'transactions', 'accounts', ['account_id'], ['id'])
    
    op.drop_constraint('transactions_category_id_fkey', 'transactions', type_='foreignkey')
    op.create_foreign_key('transactions_category_id_fkey', 'transactions', 'categories', ['category_id'], ['id'])
    
    op.drop_constraint('transactions_showcase_item_id_fkey', 'transactions', type_='foreignkey')
    op.create_foreign_key('transactions_showcase_item_id_fkey', 'transactions', 'showcase_items', ['showcase_item_id'], ['id'])
    
    op.drop_constraint('transactions_transfer_to_account_id_fkey', 'transactions', type_='foreignkey')
    op.create_foreign_key('transactions_transfer_to_account_id_fkey', 'transactions', 'accounts', ['transfer_to_account_id'], ['id'])
    
    op.drop_constraint('order_payments_transaction_id_fkey', 'order_payments', type_='foreignkey')
    op.create_foreign_key('order_payments_transaction_id_fkey', 'order_payments', 'transactions', ['transaction_id'], ['id'])
    
    op.drop_constraint('transaction_items_product_id_fkey', 'transaction_items', type_='foreignkey')
    op.create_foreign_key('transaction_items_product_id_fkey', 'transaction_items', 'products', ['product_id'], ['id'])