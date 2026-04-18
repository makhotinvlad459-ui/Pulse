from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from jose import jwt, JWTError
from app.database import get_db
from app.models import User
from app.config import settings
from app.websocket_manager import manager

router = APIRouter(tags=["websocket"])

async def get_user_from_token(token: str, db: AsyncSession) -> User | None:
    """Извлекает пользователя из JWT токена"""
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id = payload.get("sub")
        if user_id is None:
            return None
        result = await db.execute(select(User).where(User.id == int(user_id)))
        return result.scalar_one_or_none()
    except JWTError:
        return None

@router.websocket("/ws/chat/{company_id}")
async def websocket_chat(
    websocket: WebSocket,
    company_id: int,
    db: AsyncSession = Depends(get_db)
):
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=1008, reason="Missing token")
        return
    
    user = await get_user_from_token(token, db)
    if not user:
        await websocket.close(code=1008, reason="Invalid token")
        return
    
    # Проверка доступа к компании (опционально)
    
    await manager.connect_chat(company_id, websocket)
    try:
        while True:
            await websocket.receive_text()
            await websocket.send_json({"status": "pong"})
    except WebSocketDisconnect:
        manager.disconnect_chat(company_id, websocket)

@router.websocket("/ws/tasks/{company_id}")
async def websocket_tasks(
    websocket: WebSocket,
    company_id: int,
    db: AsyncSession = Depends(get_db)
):
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=1008, reason="Missing token")
        return
    
    user = await get_user_from_token(token, db)
    if not user:
        await websocket.close(code=1008, reason="Invalid token")
        return
    
    await manager.connect_task(company_id, websocket)
    try:
        while True:
            await websocket.receive_text()
            await websocket.send_json({"status": "pong"})
    except WebSocketDisconnect:
        manager.disconnect_task(company_id, websocket)

@router.websocket("/ws/user/{user_id}")
async def websocket_user(
    websocket: WebSocket,
    user_id: int,
    db: AsyncSession = Depends(get_db)
):
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
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect_user(user_id, websocket)