from fastapi import FastAPI
from app.auth import router as auth_router
from app.routers import companies,  accounts, categories, transactions, statistics, admin, chat


app = FastAPI(title="Pulse API", version="0.2.0")
app.include_router(auth_router)
app.include_router(companies.router)
app.include_router(accounts.router)
app.include_router(categories.router)
app.include_router(transactions.router)
app.include_router(statistics.router)
app.include_router(admin.router)
app.include_router(chat.router)

@app.get("/")
def root():
    return {"message": "Pulse API is running"}

@app.get("/health")
def health():
    return {"status": "ok"}