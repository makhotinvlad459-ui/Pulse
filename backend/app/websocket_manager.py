import asyncio
import json
from typing import Dict, Set
from fastapi import WebSocket
import redis.asyncio as aioredis
from app.config import settings
import aiohttp
import google.auth.transport.requests
from google.oauth2 import service_account

SERVICE_ACCOUNT_FILE = "firebase-key.json"

class ConnectionManager:
    def __init__(self):
        self.active_chat_connections: Dict[int, Set[WebSocket]] = {}
        self.active_task_connections: Dict[int, Set[WebSocket]] = {}
        self.active_user_connections: Dict[int, Set[WebSocket]] = {}
        self.redis_client = None
        self.pubsub = None
        self._running = True

    async def init_redis(self):
        print("🟢 Initializing Redis connection...")
        self.redis_client = await aioredis.from_url(settings.REDIS_URL, decode_responses=True)
        await self.redis_client.ping()
        print("✅ Redis connected")

    async def listen_redis_channels(self):
        while self._running:
            try:
                if self.redis_client is None:
                    await self.init_redis()
            
                self.pubsub = self.redis_client.pubsub()
                await self.pubsub.subscribe("pulse_events")
                print("📡 Subscribed to 'pulse_events' channel")
            
                while self._running:
                    try:
                    # 🔥 ИСПРАВЛЕНИЕ: используем timeout=1.0 и добавляем sleep
                        message = await self.pubsub.get_message(
                            ignore_subscribe_messages=True,
                            timeout=1.0
                        )
                        if message and message["type"] == "message":
                            await self._handle_redis_message(message["data"])
                        else:
                        # 👇 ВАЖНО! Даем время другим задачам
                            await asyncio.sleep(0.01)
                    except asyncio.TimeoutError:
                    # Таймаут - просто продолжаем
                        continue
                    except Exception as e:
                        print(f"❌ Redis listener error: {e}")
                        break
            except Exception as e:
                print(f"❌ Redis connection error: {e}")
                await asyncio.sleep(5)
                continue

    async def _handle_redis_message(self, data: str):
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
        self._running = False
        if self.pubsub:
            await self.pubsub.close()
        if self.redis_client:
            await self.redis_client.close()
        print("✅ Redis connections closed")

    # ... остальные методы остаются без изменений ...
    async def connect_chat(self, company_id: int, websocket: WebSocket):
        print(f'🔵 CONNECT_CHAT CALLED for company {company_id}')
        if company_id not in self.active_chat_connections:
            self.active_chat_connections[company_id] = set()
        self.active_chat_connections[company_id].add(websocket)
        print(f'✅ CONNECT_CHAT FINISHED, connections: {list(self.active_chat_connections.keys())}')

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

    async def connect_task(self, company_id: int, websocket: WebSocket):
        if company_id not in self.active_task_connections:
            self.active_task_connections[company_id] = set()
        self.active_task_connections[company_id].add(websocket)

    def disconnect_task(self, company_id: int, websocket: WebSocket):
        if company_id in self.active_task_connections:
            self.active_task_connections[company_id].discard(websocket)
            if not self.active_task_connections[company_id]:
                del self.active_task_connections[company_id]

    async def broadcast_task(self, company_id: int, message: dict):
        if not self.redis_client:
            return
        await self.redis_client.publish("pulse_events", json.dumps({
            "type": "task",
            "company_id": company_id,
            "message": message
        }))

    async def connect_user(self, user_id: int, websocket: WebSocket):
        if user_id not in self.active_user_connections:
            self.active_user_connections[user_id] = set()
        self.active_user_connections[user_id].add(websocket)

    def disconnect_user(self, user_id: int, websocket: WebSocket):
        if user_id in self.active_user_connections:
            self.active_user_connections[user_id].discard(websocket)
            if not self.active_user_connections[user_id]:
                del self.active_user_connections[user_id]

    async def send_to_user(self, user_id: int, message: dict):
        if not self.redis_client:
            return
        await self.redis_client.publish("pulse_events", json.dumps({
            "type": "user",
            "user_id": user_id,
            "message": message
        }))

    async def notify_company_members(self, company_id: int, message: dict, db):
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

def get_firebase_token():
    credentials = service_account.Credentials.from_service_account_file(
        SERVICE_ACCOUNT_FILE,
        scopes=['https://www.googleapis.com/auth/firebase.messaging']
    )
    auth_req = google.auth.transport.requests.Request()
    credentials.refresh(auth_req)
    return credentials.token

async def send_push_notification(fcm_token: str, title: str, body: str, data: dict = None):
    if not fcm_token:
        return
    
    try:
        access_token = get_firebase_token()
        url = f"https://fcm.googleapis.com/v1/projects/pulse-yourmoney/messages:send"
        
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json"
        }
        
        payload = {
            "message": {
                "token": fcm_token,
                "notification": {
                    "title": title,
                    "body": body
                },
                "webpush": {
                    "fcm_options": {
                        "link": "https://pulse-yourmoney.com"
                    }
                }
            }
        }
        
        async with aiohttp.ClientSession() as session:
            async with session.post(url, headers=headers, json=payload) as resp:
                if resp.status != 200:
                    print(f"Push error: {await resp.text()}")
    except Exception as e:
        print(f"Push exception: {e}")            


manager = ConnectionManager()