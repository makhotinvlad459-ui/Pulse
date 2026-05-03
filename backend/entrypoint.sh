#!/bin/bash
set -e

wait_for_db() {
    echo "Waiting for database..."
    while ! pg_isready -h db -U $POSTGRES_USER -d $POSTGRES_DB; do
        sleep 1
    done
    echo "Database is ready."
}

run_migrations() {
    echo "Running migrations..."
    alembic upgrade head
}

init_permissions() {
    echo "Initializing permissions..."
    python /app/init_permissions_sync.py
}

wait_for_db
run_migrations
init_permissions

exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload