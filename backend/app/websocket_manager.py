import asyncio
import json
from typing import Dict, Set
from fastapi import WebSocket
import redis.asyncio as aioredis
from app.config import settings


class ConnectionManager:
    def __init__(self):
        self.active_chat_connections: Dict[int, Set[WebSocket]] = {}
        self.active_task_connections: Dict[int, Set[WebSocket]] = {}
        self.active_user_connections: Dict[int, Set[WebSocket]] = {}
        self.redis_client = None
        self.pubsub = None

    # ========== REDIS ИНИЦИАЛИЗАЦИЯ ==========
    async def init_redis(self):
        """Инициализация Redis клиента"""
        print("🟢 Initializing Redis connection...")
        self.redis_client = await aioredis.from_url(settings.REDIS_URL, decode_responses=True)
        await self.redis_client.ping()
        print("✅ Redis connected")

    async def listen_redis_channels(self):
        """Фоновая задача – слушает Redis и рассылает локальным клиентам"""
        self.pubsub = self.redis_client.pubsub()
        await self.pubsub.subscribe("pulse_events")
        print("📡 Subscribed to 'pulse_events' channel")
        
        try:
            async for message in self.pubsub.listen():
                if message["type"] == "message":
                    await self._handle_redis_message(message["data"])
        except asyncio.CancelledError:
            print("🔴 Redis listener cancelled")
            if self.pubsub:
                await self.pubsub.unsubscribe("pulse_events")
        except Exception as e:
            print(f"❌ Redis listener error: {e}")

    async def _handle_redis_message(self, data: str):
        """Обрабатывает сообщение из Redis и отправляет локальным клиентам"""
        try:
            payload = json.loads(data)
            event_type = payload.get("type")
            
            if event_type == "chat":
                company_id = payload["company_id"]
                message = payload["message"]
                if company_id in self.active_chat_connections:
                    for connection in self.active_chat_connections[company_id]:
                        try:
                            await connection.send_json(message)
                        except Exception:
                            pass
                            
            elif event_type == "task":
                company_id = payload["company_id"]
                message = payload["message"]
                if company_id in self.active_task_connections:
                    for connection in self.active_task_connections[company_id]:
                        try:
                            await connection.send_json(message)
                        except Exception:
                            pass
                            
            elif event_type == "user":
                user_id = payload["user_id"]
                message = payload["message"]
                if user_id in self.active_user_connections:
                    for connection in self.active_user_connections[user_id]:
                        try:
                            await connection.send_json(message)
                        except Exception:
                            pass
        except Exception as e:
            print(f"❌ Error handling Redis message: {e}")

    async def close_redis(self):
        """Закрывает Redis соединения"""
        if self.pubsub:
            await self.pubsub.close()
        if self.redis_client:
            await self.redis_client.close()
        print("✅ Redis connections closed")

    # ========== ЧАТ ==========
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

        print(f"📢 broadcast_chat: company={company_id}")
        print(f"📢 Message type: {message.get('type')}")
    
        if not self.redis_client:
            print("❌ Redis client is None!")
            return
    
        try:
            payload = json.dumps({
            "type": "chat",
            "company_id": company_id,
            "message": message
            })
            await self.redis_client.publish("pulse_events", payload)
            print(f"✅ Published to Redis channel 'pulse_events'")
        except Exception as e:
            print(f"❌ Redis publish error: {e}")

    # ========== ЗАДАЧИ ==========
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
        """Публикует сообщение о задачах в Redis"""
        if not self.redis_client:
            return
        await self.redis_client.publish("pulse_events", json.dumps({
            "type": "task",
            "company_id": company_id,
            "message": message
        }))

    # ========== ПОЛЬЗОВАТЕЛЬСКИЕ УВЕДОМЛЕНИЯ ==========
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
        """Публикует уведомление пользователю в Redis"""
        if not self.redis_client:
            return
        await self.redis_client.publish("pulse_events", json.dumps({
            "type": "user",
            "user_id": user_id,
            "message": message
        }))

    async def notify_company_members(self, company_id: int, message: dict, db):
        """Получает всех членов компании и отправляет каждому через Redis"""
        from sqlalchemy import select
        from app.models import Company, CompanyMember
        
        result = await db.execute(select(Company.founder_id).where(Company.id == company_id))
        founder_id = result.scalar_one_or_none()
        
        result = await db.execute(select(CompanyMember.user_id).where(CompanyMember.company_id == company_id))
        member_ids = [row[0] for row in result.all()]
        
        if founder_id and founder_id not in member_ids:
            member_ids.append(founder_id)
        
        for uid in member_ids:
            await self.send_to_user(uid, message)


manager = ConnectionManager()