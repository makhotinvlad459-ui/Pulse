from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_
from sqlalchemy.orm import selectinload
from typing import List, Optional
from datetime import datetime
from pydantic import BaseModel

from app.database import get_db
from app.models import User, Company, Task, TaskStatus, CompanyMember, UserRole
from app.deps import get_current_user
from app.websocket_manager import manager

router = APIRouter(prefix="/tasks", tags=["tasks"])

class TaskCreate(BaseModel):
    assignee_id: Optional[int] = None
    title: str
    description: Optional[str] = None
    deadline: Optional[datetime] = None

class TaskResponse(BaseModel):
    id: int
    company_id: int
    author_id: int
    author_name: str
    assignee_id: Optional[int]
    assignee_name: Optional[str]
    title: str
    description: Optional[str]
    status: str
    created_at: datetime
    updated_at: datetime
    deadline: Optional[datetime]

    class Config:
        from_attributes = True

class TaskStatusUpdate(BaseModel):
    status: str  # 'accepted', 'completed', 'failed'

async def _can_manage_tasks(company_id: int, current_user: User, db: AsyncSession) -> bool:
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
        if result.scalar_one_or_none():
            return True
    result = await db.execute(
        select(CompanyMember).where(
            CompanyMember.company_id == company_id,
            CompanyMember.user_id == current_user.id,
            CompanyMember.role_in_company == 'manager'
        )
    )
    return result.scalar_one_or_none() is not None

@router.get("/", response_model=List[TaskResponse])
async def get_tasks(
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    can_manage = await _can_manage_tasks(company_id, current_user, db)
    if can_manage:
        query = select(Task).where(Task.company_id == company_id)
    else:
        query = select(Task).where(
            Task.company_id == company_id,
            or_(
                Task.assignee_id == current_user.id,
                Task.author_id == current_user.id
            )
        )
    query = query.order_by(Task.created_at.desc())
    query = query.options(
        selectinload(Task.author),
        selectinload(Task.assignee)
    )
    result = await db.execute(query)
    tasks = result.scalars().all()
    response = []
    for t in tasks:
        response.append(TaskResponse(
            id=t.id,
            company_id=t.company_id,
            author_id=t.author_id,
            author_name=t.author.display_name,
            assignee_id=t.assignee_id,
            assignee_name=t.assignee.display_name if t.assignee else None,
            title=t.title,
            description=t.description,
            status=t.status.value,
            created_at=t.created_at,
            updated_at=t.updated_at,
            deadline=t.deadline,
        ))
    return response

@router.post("/", response_model=TaskResponse)
async def create_task(
    company_id: int,
    task_data: TaskCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="You are not a member of this company")
    
    new_task = Task(
        company_id=company_id,
        author_id=current_user.id,
        assignee_id=task_data.assignee_id,
        title=task_data.title,
        description=task_data.description,
        deadline=task_data.deadline,
        status=TaskStatus.PENDING
    )
    db.add(new_task)
    await db.commit()
    await db.refresh(new_task)
    await db.refresh(new_task, attribute_names=['author', 'assignee'])
    
    # WebSocket для задач (внутри компании)
    await manager.broadcast_task(company_id, {
        "type": "new_task",
        "task": {
            "id": new_task.id,
            "title": new_task.title,
            "description": new_task.description,
            "status": new_task.status.value,
            "author_id": new_task.author_id,
            "author_name": new_task.author.display_name,
            "assignee_id": new_task.assignee_id,
            "assignee_name": new_task.assignee.display_name if new_task.assignee else None,
            "deadline": new_task.deadline.isoformat() if new_task.deadline else None,
            "created_at": new_task.created_at.isoformat(),
            "updated_at": new_task.updated_at.isoformat(),
        }
    })
    
    # Уведомление для главного экрана (через пользовательские WebSocket)
    await manager.notify_company_members(company_id, {
        "type": "new_task",
        "company_id": company_id
    }, db)
    
    return TaskResponse(
        id=new_task.id,
        company_id=new_task.company_id,
        author_id=new_task.author_id,
        author_name=new_task.author.display_name,
        assignee_id=new_task.assignee_id,
        assignee_name=new_task.assignee.display_name if new_task.assignee else None,
        title=new_task.title,
        description=new_task.description,
        status=new_task.status.value,
        created_at=new_task.created_at,
        updated_at=new_task.updated_at,
        deadline=new_task.deadline,
    )

@router.patch("/{task_id}/status")
async def update_task_status(
    task_id: int,
    company_id: int,
    status_data: TaskStatusUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
    else:
        result = await db.execute(select(Company).join(CompanyMember).where(Company.id == company_id, CompanyMember.user_id == current_user.id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Company not found or access denied")
    
    result = await db.execute(select(Task).where(Task.id == task_id, Task.company_id == company_id))
    task = result.scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    can_change = (current_user.id == task.assignee_id) or await _can_manage_tasks(company_id, current_user, db)
    if not can_change:
        raise HTTPException(status_code=403, detail="Not authorized to change status")
    
    new_status = status_data.status
    if new_status not in ['accepted', 'completed', 'failed']:
        raise HTTPException(status_code=400, detail="Invalid status")
    old_status = task.status.value
    task.status = TaskStatus(new_status)
    task.updated_at = datetime.utcnow()
    await db.commit()
    
    await manager.broadcast_task(company_id, {
        "type": "update_task_status",
        "task_id": task.id,
        "old_status": old_status,
        "new_status": new_status,
        "updated_at": task.updated_at.isoformat(),
    })
    
    await manager.notify_company_members(company_id, {
        "type": "update_task",
        "company_id": company_id
    }, db)
    
    return {"detail": "Status updated"}

@router.delete("/{task_id}")
async def delete_task(
    task_id: int,
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(Task).where(Task.id == task_id, Task.company_id == company_id))
    task = result.scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    can_delete = (current_user.id == task.author_id) or await _can_manage_tasks(company_id, current_user, db)
    if not can_delete:
        raise HTTPException(status_code=403, detail="Not authorized to delete this task")
    
    await db.delete(task)
    await db.commit()
    
    await manager.broadcast_task(company_id, {
        "type": "delete_task",
        "task_id": task_id,
    })
    
    await manager.notify_company_members(company_id, {
        "type": "delete_task",
        "company_id": company_id
    }, db)
    
    return {"detail": "Task deleted"}