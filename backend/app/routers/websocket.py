import asyncio
import json
import logging
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from jose import jwt, JWTError
from app.database import get_db
from app.models import User, Company, CompanyMember
from app.config import settings
from app.websocket_manager import manager

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

router = APIRouter(tags=["websocket"])

async def get_user_from_token(token: str, db: AsyncSession) -> User | None:
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id = payload.get("sub")
        if user_id is None:
            return None
        result = await db.execute(select(User).where(User.id == int(user_id)))
        return result.scalar_one_or_none()
    except JWTError as e:
        print(f"JWT Error: {e}")
        return None

async def check_company_access(company_id: int, user: User, db: AsyncSession) -> bool:
    print(f"Checking access for user {user.id} (role={user.role}) to company {company_id}")
    if user.role == "founder":
        result = await db.execute(
            select(Company).where(Company.id == company_id, Company.founder_id == user.id)
        )
    else:
        result = await db.execute(
            select(Company).join(CompanyMember).where(
                Company.id == company_id, 
                CompanyMember.user_id == user.id
            )
        )
    company = result.scalar_one_or_none()
    print(f"Company access result: {company is not None}")
    return company is not None

@router.websocket("/ws/chat/{company_id}")
async def websocket_chat(
    websocket: WebSocket,
    company_id: int,
    db: AsyncSession = Depends(get_db)
):
    print(f"🔴 WEBSOCKET CHAT CALLED for company {company_id}")
    await websocket.accept()
    print("✅ WebSocket accepted")
    
    token = websocket.query_params.get("token")
    print(f"Token: {token[:50] if token else 'None'}...")
    
    if not token:
        print("❌ No token")
        await websocket.close(code=1008, reason="Missing token")
        return
    
    user = await get_user_from_token(token, db)
    print(f"User found: {user.id if user else None}")
    
    if not user:
        print("❌ Invalid token")
        await websocket.close(code=1008, reason="Invalid token")
        return
    
    if not await check_company_access(company_id, user, db):
        print(f"❌ Access denied to company {company_id}")
        await websocket.close(code=1008, reason="Access denied to this company")
        return
    
    print(f"✅ Access granted, connecting to chat {company_id}")
    await manager.connect_chat(company_id, websocket)
    
    # Отправляем пинг клиенту каждые 25 секунд
    try:
        while True:
            try:
                # Ждем сообщение от клиента с таймаутом 25 секунд
                data = await asyncio.wait_for(websocket.receive_text(), timeout=25.0)
                print(f"📨 Received from client: {data}")
            except asyncio.TimeoutError:
                # Таймаут - отправляем пинг клиенту
                await websocket.send_text(json.dumps({"type": "ping"}))
                print("📡 Ping sent to client")
    except WebSocketDisconnect:
        print(f"🔌 Chat WebSocket disconnected for company {company_id}")
        manager.disconnect_chat(company_id, websocket)
    except Exception as e:
        print(f"❌ WebSocket error: {e}")
        manager.disconnect_chat(company_id, websocket)

@router.websocket("/ws/tasks/{company_id}")
async def websocket_tasks(
    websocket: WebSocket,
    company_id: int,
    db: AsyncSession = Depends(get_db)
):
    await websocket.accept()
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=1008, reason="Missing token")
        return
    user = await get_user_from_token(token, db)
    if not user:
        await websocket.close(code=1008, reason="Invalid token")
        return
    if not await check_company_access(company_id, user, db):
        await websocket.close(code=1008, reason="Access denied")
        return
    await manager.connect_task(company_id, websocket)
    try:
        while True:
            try:
                await asyncio.wait_for(websocket.receive_text(), timeout=30.0)
            except asyncio.TimeoutError:
                await websocket.send_text(json.dumps({"type": "ping"}))
    except WebSocketDisconnect:
        manager.disconnect_task(company_id, websocket)

@router.websocket("/ws/user/{user_id}")
async def websocket_user(
    websocket: WebSocket,
    user_id: int,
    db: AsyncSession = Depends(get_db)
):
    await websocket.accept()
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=1008, reason="Missing token")
        return
    user = await get_user_from_token(token, db)
    if not user or user.id != user_id:
        await websocket.close(code=1008, reason="Unauthorized")
        return
    await manager.connect_user(user_id, websocket)
    try:
        while True:
            try:
                await asyncio.wait_for(websocket.receive_text(), timeout=30.0)
            except asyncio.TimeoutError:
                await websocket.send_text(json.dumps({"type": "ping"}))
    except WebSocketDisconnect:
        manager.disconnect_user(user_id, websocket)