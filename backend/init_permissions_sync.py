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

    permissions = [
        ('view_operations', 'Просмотр операций'),
        ('create_transaction', 'Создание операций'),
        ('edit_transaction', 'Редактирование операций'),
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
        ('view_accounts', 'Просмотр счетов'),
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
    ]

    for name, desc in permissions:
        # Проверяем, есть ли уже
        exists = session.execute(text("SELECT 1 FROM permissions WHERE name = :name"), {"name": name}).fetchone()
        if not exists:
            session.execute(text("INSERT INTO permissions (name, description) VALUES (:name, :desc)"), {"name": name, "desc": desc})
    session.commit()
    print("✅ Права добавлены")

if __name__ == "__main__":
    main()