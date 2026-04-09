#!/bin/bash
set -e

# Запуск миграций
alembic upgrade head

# Запуск Uvicorn
exec uvicorn app.main:app --host 0.0.0.0 --port 8000
