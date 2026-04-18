from typing import Dict, Set
from fastapi import WebSocket


class ConnectionManager:
    def __init__(self):
        self.active_chat_connections: Dict[int, Set[WebSocket]] = {}
        self.active_task_connections: Dict[int, Set[WebSocket]] = {}
        self.active_user_connections: Dict[int, Set[WebSocket]] = {}

    # ----- Чат -----
    async def connect_chat(self, company_id: int, websocket: WebSocket):
        await websocket.accept()
        if company_id not in self.active_chat_connections:
            self.active_chat_connections[company_id] = set()
        self.active_chat_connections[company_id].add(websocket)

    def disconnect_chat(self, company_id: int, websocket: WebSocket):
        if company_id in self.active_chat_connections:
            self.active_chat_connections[company_id].discard(websocket)
            if not self.active_chat_connections[company_id]:
                del self.active_chat_connections[company_id]

    async def broadcast_chat(self, company_id: int, message: dict):
        if company_id in self.active_chat_connections:
            for connection in self.active_chat_connections[company_id]:
                try:
                    await connection.send_json(message)
                except Exception:
                    pass

    # ----- Задачи -----
    async def connect_task(self, company_id: int, websocket: WebSocket):
        await websocket.accept()
        if company_id not in self.active_task_connections:
            self.active_task_connections[company_id] = set()
        self.active_task_connections[company_id].add(websocket)

    def disconnect_task(self, company_id: int, websocket: WebSocket):
        if company_id in self.active_task_connections:
            self.active_task_connections[company_id].discard(websocket)
            if not self.active_task_connections[company_id]:
                del self.active_task_connections[company_id]

    async def broadcast_task(self, company_id: int, message: dict):
        if company_id in self.active_task_connections:
            for connection in self.active_task_connections[company_id]:
                try:
                    await connection.send_json(message)
                except Exception:
                    pass

    # ----- Пользовательские уведомления -----
    async def connect_user(self, user_id: int, websocket: WebSocket):
        await websocket.accept()
        if user_id not in self.active_user_connections:
            self.active_user_connections[user_id] = set()
        self.active_user_connections[user_id].add(websocket)

    def disconnect_user(self, user_id: int, websocket: WebSocket):
        if user_id in self.active_user_connections:
            self.active_user_connections[user_id].discard(websocket)
            if not self.active_user_connections[user_id]:
                del self.active_user_connections[user_id]

    async def send_to_user(self, user_id: int, message: dict):
        print(f"🔵 send_to_user: user {user_id}, message {message}")
        if user_id in self.active_user_connections:
            for connection in self.active_user_connections[user_id]:
                try:
                    await connection.send_json(message)
                    print(f"✅ sent to user {user_id}")
                except Exception as e:
                    print(f"❌ error sending to user {user_id}: {e}")
        else:
            print(f"⚠️ user {user_id} has no active WebSocket")

    async def notify_company_members(self, company_id: int, message: dict, db):
        print(f"🔵 notify_company_members: company {company_id}, message {message}")
        from sqlalchemy import select
        from app.models import Company, CompanyMember
        # Получаем founder_id
        result = await db.execute(select(Company.founder_id).where(Company.id == company_id))
        founder_id = result.scalar_one_or_none()
        # Получаем всех членов из company_members
        result = await db.execute(select(CompanyMember.user_id).where(CompanyMember.company_id == company_id))
        member_ids = [row[0] for row in result.all()]
        if founder_id and founder_id not in member_ids:
            member_ids.append(founder_id)
        print(f"🔵 Members of company {company_id}: {member_ids}")
        for uid in member_ids:
            await self.send_to_user(uid, message)


manager = ConnectionManager()