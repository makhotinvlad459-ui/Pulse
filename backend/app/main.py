from fastapi import FastAPI
from app.auth import router as auth_router
from app.routers import subscription, counterparties, companies, accounts, categories, transactions, statistics, admin, showcase, chat, tasks, websocket, notifications, products, permissions, orders
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os

app = FastAPI(title="Pulse API", version="0.2.0")

# 1. Собираем все роутеры в один список
routers = [
    auth_router, companies.router, accounts.router, categories.router,
    transactions.router, statistics.router, admin.router, chat.router,
    tasks.router, websocket.router, notifications.router, products.router,
    showcase.router, permissions.router, orders.router, counterparties.router,
    subscription.router
]

for router in routers:
    # Сначала безопасно собираем дубликаты путей из самого роутера
    routes_to_add = []
    for route in router.routes:
        # Если эндпоинт в файле (например, accounts.py) заканчивается на "/"
        if route.path.endswith("/") and len(route.path) > 1:
            path_without_slash = route.path[:-1]
            routes_to_add.append((path_without_slash, route))

    # Добавляем бесслешевые зеркала в сам роутер перед его монтированием
    for path, route in routes_to_add:
        # Проверяем, чтобы разработчик случайно не создал два одинаковых пути
        if path not in [r.path for r in router.routes]:
            router.add_api_route(
                path,
                route.endpoint,
                methods=route.methods,
                dependencies=route.dependencies,
                response_model=route.response_model,
                tags=route.tags,
                summary=route.summary,
                description=route.description
            )
            
    # Теперь монтируем роутер со всеми его оригинальными и дублирующими путями
    app.include_router(router)


# Статика
UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["Authorization", "Content-Type", "Accept"],
)

@app.get("/")
def root():
    return {"message": "Pulse API is running"}

@app.get("/health")
def health():
    return {"status": "ok"}