from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from uvicorn.middleware.proxy_headers import ProxyHeadersMiddleware
import os
import asyncio
from app.config import settings
import firebase_admin
from firebase_admin import credentials

from app.auth import router as auth_router
from app.routers import subscription, journal, counterparties, companies, accounts, categories, transactions, statistics, admin, showcase, chat, tasks, websocket, notifications, products, permissions, orders
from app.websocket_manager import manager


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Управление жизненным циклом приложения"""
    
    # === ИНИЦИАЛИЗАЦИЯ FIREBASE ===
    print("🔥 [Startup] Инициализация Firebase SDK...")
    try:
        # Проверяем, не инициализировано ли приложение ранее (чтобы докер не ругался при перезапусках)
        if not firebase_admin._apps:
            cred = credentials.Certificate(settings.FIREBASE_KEY_PATH)
            firebase_admin.initialize_app(cred, {
                'storageBucket': settings.FIREBASE_STORAGE_BUCKET
            })
        print("✅ [Startup] Firebase успешно подключен!")
    except Exception as e:
        print(f"❌ [Startup] Ошибка инициализации Firebase: {e}")
    # ===============================

    print("🚀 [Startup] Инициализация Redis клиента...")
    await manager.init_redis()
    
    # Запускаем фоновую задачу прослушивания Redis
    redis_listener_task = asyncio.create_task(manager.listen_redis_channels())
    print("✅ [Startup] Фоновое прослушивание Redis Pub/Sub запущено")
    
    yield
    
    print("🛑 [Shutdown] Закрытие ресурсов...")
    redis_listener_task.cancel()
    await manager.close_redis()
    print("✅ [Shutdown] Ресурсы закрыты")


app = FastAPI(
    title="Pulse API",
    version="0.2.0",
    lifespan=lifespan
)

# 1. Прокси заголовки (должна быть САМОЙ ПЕРВОЙ)
app.add_middleware(ProxyHeadersMiddleware, trusted_hosts=["*"])

routers = [
    auth_router,journal.router, companies.router, accounts.router, categories.router,
    transactions.router, statistics.router, admin.router, chat.router,
    tasks.router, notifications.router, products.router,
    showcase.router, permissions.router, orders.router, counterparties.router,
    subscription.router
]

for router in routers:
    routes_to_add = []
    for route in router.routes:
        if route.path.endswith("/") and len(route.path) > 1:
            path_without_slash = route.path[:-1]
            routes_to_add.append((path_without_slash, route))

    for path, route in routes_to_add:
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
    
    app.include_router(router, prefix="/api")
    app.include_router(websocket.router)

# Статика
UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

# CORS (после ProxyHeadersMiddleware)
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