from fastapi import FastAPI
from app.auth import router as auth_router
from app.routers import companies, accounts, categories, transactions, statistics, admin, showcase, chat, tasks, websocket, notifications, products, permissions
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os

app = FastAPI(title="Pulse API", version="0.2.0")

# Подключаем маршруты
app.include_router(auth_router)
app.include_router(companies.router)
app.include_router(accounts.router)
app.include_router(categories.router)
app.include_router(transactions.router)
app.include_router(statistics.router)
app.include_router(admin.router)
app.include_router(chat.router)
app.include_router(tasks.router)
app.include_router(websocket.router)
app.include_router(notifications.router)
app.include_router(products.router)
app.include_router(showcase.router)
app.include_router(permissions.router)   # Новый роутер для прав

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
    allow_headers=["*"],
)

# ========== Инициализация базы данных и прав ==========
@app.on_event("startup")
async def startup_event():
    from app.database import init_db, init_permissions
    await init_db()
    await init_permissions()

# ========== Корневые эндпоинты ==========
@app.get("/")
def root():
    return {"message": "Pulse API is running"}

@app.get("/health")
def health():
    return {"status": "ok"}