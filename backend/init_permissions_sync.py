import os
import sys
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from app.config import settings

def main():
    sync_url = settings.DATABASE_URL.replace('+asyncpg', '').replace('postgresql+asyncpg', 'postgresql')
    engine = create_engine(sync_url)
    Session = sessionmaker(bind=engine)
    session = Session()

    # --- СОЗДАЁМ ТАБЛИЦУ, ЕСЛИ ЕЁ НЕТ ---
    session.execute(text("""
        CREATE TABLE IF NOT EXISTS permissions (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100) NOT NULL UNIQUE,
            description VARCHAR(255)
        )
    """))
    session.commit()

    # --- ГАРАНТИРУЕМ АВТОИНКРЕМЕНТ ---
    session.execute(text("""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_name='permissions' AND column_name='id'
                AND column_default IS NOT NULL AND column_default LIKE 'nextval%'
            ) THEN
                CREATE SEQUENCE IF NOT EXISTS permissions_id_seq;
                ALTER TABLE permissions ALTER COLUMN id SET DEFAULT nextval('permissions_id_seq');
                PERFORM setval('permissions_id_seq', COALESCE((SELECT MAX(id) FROM permissions), 0) + 1, false);
            END IF;
        END
        $$;
    """))
    session.commit()

    # --- СПИСОК ВСЕХ ПРАВ (включая журнал) ---
    permissions = [
        ('view_operations', 'Просмотр операций'),
        ('create_transaction', 'Создание операций'),
        ('edit_transaction', 'Редактирование операций'),
        ('view_accounts', 'Просмотр счетов'),
        ('view_counterparties', 'Просмотр списка контрагентов'),
        ('edit_counterparties', 'Редактирование контрагентов'),
        ('view_showcase', 'Просмотр витрины'),
        ('edit_showcase', 'Редактирование витрины'),
        ('sell_from_showcase', 'Продажа с витрины'),
        ('view_chat', 'Просмотр чата'),
        ('send_messages', 'Отправка сообщений'),
        ('view_tasks', 'Просмотр задач'),
        ('create_task', 'Создание задач'),
        ('edit_task', 'Редактирование задач'),
        ('manage_employees', 'Управление сотрудниками'),
        ('manage_permissions', 'Управление правами'),
        ('create_account', 'Создание счетов'),
        ('manage_categories', 'Управление категориями'),
        ('view_reports', 'Просмотр отчётов'),
        ('edit_company', 'Редактирование компании'),
        ('view_archive', 'Просмотр архива'),
        ('view_documents', 'Просмотр документов'),
        ('create_documents', 'Создание документов'),
        ('edit_documents', 'Редактирование документов'),
        ('view_products', 'Просмотр товаров'),
        ('create_product', 'Создание товаров'),
        ('edit_product', 'Редактирование товаров'),
        ('view_materials', 'Просмотр материалов'),
        ('create_material', 'Создание материалов'),
        ('edit_material', 'Редактирование материалов'),
        ('view_orders', 'Просмотр заказов'),
        ('edit_orders', 'Редактирование заказов'),
        ('view_journal', 'Просмотр журнала'),
        ('create_journal', 'Создание записей в журнале'),
        ('edit_journal', 'Редактирование записей'),
        ('delete_journal', 'Удаление записей'),
        ('complete_journal', 'Отметка записей выполненными (создание транзакций)'),
    ]

    # --- ДОБАВЛЯЕМ НЕДОСТАЮЩИЕ ПРАВА ---
    for name, desc in permissions:
        exists = session.execute(text("SELECT 1 FROM permissions WHERE name = :name"), {"name": name}).fetchone()
        if not exists:
            session.execute(text("INSERT INTO permissions (name, description) VALUES (:name, :desc)"), {"name": name, "desc": desc})
    session.commit()

    # --- ВЫДАЁМ ВСЕ ПРАВА ВСЕМ УЧРЕДИТЕЛЯМ (ЕСЛИ НЕТ) ---
    all_perms = session.execute(text("SELECT id FROM permissions")).fetchall()
    founders = session.execute(text("""
        SELECT cm.id, cm.user_id
        FROM company_members cm
        JOIN users u ON u.id = cm.user_id
        WHERE u.role = 'FOUNDER'
    """)).fetchall()

    for perm_row in all_perms:
        perm_id = perm_row[0]
        for member_id, user_id in founders:
            exists = session.execute(
                text("SELECT 1 FROM company_member_permissions WHERE member_id = :mid AND permission_id = :pid"),
                {"mid": member_id, "pid": perm_id}
            ).fetchone()
            if not exists:
                session.execute(
                    text("""
                        INSERT INTO company_member_permissions (member_id, permission_id, granted_by, granted_at)
                        VALUES (:mid, :pid, :uid, NOW())
                    """),
                    {"mid": member_id, "pid": perm_id, "uid": user_id}
                )
    session.commit()

    print("✅ Права добавлены и выданы учредителям")

if __name__ == "__main__":
    main()