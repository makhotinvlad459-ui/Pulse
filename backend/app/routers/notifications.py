from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, union, distinct
from typing import Dict, Any
from datetime import datetime

from app.database import get_db
from app.models import User, Company, CompanyMember, ChatMessage, Task, TaskStatus, UserChatVisit
from app.deps import get_current_user

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("/unread-counts")
async def get_unread_counts(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
) -> Dict[int, Dict[str, int]]:
    """
    Возвращает для каждой компании пользователя количество непрочитанных сообщений
    и ожидающих задач.
    
    Формат ответа:
    {
        company_id: {
            "unread_messages": int,
            "pending_tasks": int,
            "total": int
        },
        ...
    }
    """
    # 1. Получаем список ID компаний, к которым имеет доступ пользователь
    # Для founder: компании, где он founder
    # Для employee: компании через CompanyMember
    company_ids_set = set()
    
    if current_user.role.value == "founder":  # UserRole.FOUNDER.value
        result = await db.execute(
            select(Company.id).where(Company.founder_id == current_user.id)
        )
        founder_companies = result.scalars().all()
        company_ids_set.update(founder_companies)
    
    # Всегда добавляем компании через членство (на случай если founder также является членом)
    result = await db.execute(
        select(CompanyMember.company_id).where(CompanyMember.user_id == current_user.id)
    )
    member_companies = result.scalars().all()
    company_ids_set.update(member_companies)
    
    if not company_ids_set:
        return {}
    
    company_ids = list(company_ids_set)
    
    # 2. Для каждой компании получаем last_visit_at из UserChatVisit
    # Создаём словарь: company_id -> last_visit_at (datetime или None)
    visits_result = await db.execute(
        select(UserChatVisit.company_id, UserChatVisit.last_visit_at)
        .where(
            UserChatVisit.user_id == current_user.id,
            UserChatVisit.company_id.in_(company_ids)
        )
    )
    last_visit_map = {row[0]: row[1] for row in visits_result.all()}
    
    # 3. Подсчёт непрочитанных сообщений по каждой компании
    # Выполняем один запрос с группировкой
    unread_counts = {}
    if company_ids:
        # Запрос для сообщений, созданных после last_visit (или если нет записи – считаем 0)
        # Для компаний без записи last_visit_at считаем непрочитанные = 0
        # Сделаем LEFT JOIN с подзапросом last_visit, но проще: для каждой компании отдельно?
        # Оптимально: получить все сообщения и отфильтровать, но компаний не тысячи.
        # Для простоты и понятности сделаем цикл по компаниям – их обычно немного.
        for cid in company_ids:
            last_visit = last_visit_map.get(cid)
            if last_visit is not None:
                result = await db.execute(
                    select(func.count(ChatMessage.id))
                    .where(ChatMessage.company_id == cid)
                    .where(ChatMessage.created_at > last_visit)
                )
                unread = result.scalar() or 0
            else:
                unread = 0
            unread_counts[cid] = unread
    
    # 4. Подсчёт ожидающих задач (status = pending)
    pending_counts = {}
    if company_ids:
        result = await db.execute(
            select(Task.company_id, func.count(Task.id))
            .where(Task.company_id.in_(company_ids))
            .where(Task.status == TaskStatus.PENDING)
            .group_by(Task.company_id)
        )
        for row in result.all():
            pending_counts[row[0]] = row[1]
        # Для компаний без pending задач ставим 0
        for cid in company_ids:
            if cid not in pending_counts:
                pending_counts[cid] = 0
    
    # 5. Формируем ответ
    response = {}
    for cid in company_ids:
        unread = unread_counts.get(cid, 0)
        pending = pending_counts.get(cid, 0)
        response[cid] = {
            "unread_messages": unread,
            "pending_tasks": pending,
            "total": unread + pending
        }
    
    return response