from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete   # добавлен delete
from sqlalchemy.orm import selectinload
from typing import List
from pydantic import BaseModel

from app.database import get_db
from app.models import User, Company, CompanyMember, Permission, CompanyMemberPermission, UserRole
from app.deps import get_current_user

router = APIRouter(prefix="/permissions", tags=["permissions"])

class PermissionResponse(BaseModel):
    id: int
    name: str
    description: str | None

class MemberPermissionsResponse(BaseModel):
    member_id: int
    user_id: int
    user_full_name: str
    permissions: List[str]

class UpdatePermissionsRequest(BaseModel):
    permission_names: List[str]

async def _can_manage_permissions(company_id: int, current_user: User, db: AsyncSession) -> bool:
    if current_user.role == UserRole.FOUNDER:
        result = await db.execute(select(Company).where(Company.id == company_id, Company.founder_id == current_user.id))
        if result.scalar_one_or_none():
            return True
    member = await db.execute(
        select(CompanyMember).where(CompanyMember.company_id == company_id, CompanyMember.user_id == current_user.id)
    )
    member = member.scalar_one_or_none()
    if not member:
        return False
    perm = await db.execute(
        select(CompanyMemberPermission).join(Permission).where(
            CompanyMemberPermission.member_id == member.id,
            Permission.name == 'manage_permissions'
        )
    )
    return perm.scalar_one_or_none() is not None

@router.get("/list")
async def get_all_permissions(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user)
) -> List[PermissionResponse]:
    result = await db.execute(select(Permission).order_by(Permission.name))
    perms = result.scalars().all()
    return [PermissionResponse(id=p.id, name=p.name, description=p.description) for p in perms]

@router.get("/company/{company_id}")
async def get_company_permissions(
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
) -> List[MemberPermissionsResponse]:
    if not await _can_manage_permissions(company_id, current_user, db):
        raise HTTPException(status_code=403, detail="Not allowed to view permissions")
    members_res = await db.execute(
        select(CompanyMember)
        .where(CompanyMember.company_id == company_id)
        .options(selectinload(CompanyMember.user))
    )
    members = members_res.scalars().all()
    result = []
    for m in members:
        perms_res = await db.execute(
            select(Permission.name)
            .join(CompanyMemberPermission)
            .where(CompanyMemberPermission.member_id == m.id)
        )
        perms = [row[0] for row in perms_res.all()]
        result.append(MemberPermissionsResponse(
            member_id=m.id,
            user_id=m.user_id,
            user_full_name=m.user.display_name,
            permissions=perms
        ))
    return result

@router.put("/company/{company_id}/member/{member_id}")
async def update_member_permissions(
    company_id: int,
    member_id: int,
    req: UpdatePermissionsRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not await _can_manage_permissions(company_id, current_user, db):
        raise HTTPException(status_code=403, detail="Not allowed to manage permissions")
    
    # Проверяем, что member относится к этой компании
    member = await db.execute(
        select(CompanyMember).where(CompanyMember.id == member_id, CompanyMember.company_id == company_id)
    )
    member = member.scalar_one_or_none()
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")
    
    # Запрещаем менять свои права (кроме учредителя)
    if member.user_id == current_user.id and current_user.role != UserRole.FOUNDER:
        raise HTTPException(status_code=403, detail="You cannot change your own permissions")
    
    # Удаляем все старые права
    await db.execute(delete(CompanyMemberPermission).where(CompanyMemberPermission.member_id == member_id))
    
    # Добавляем новые
    for perm_name in req.permission_names:
        perm = await db.execute(select(Permission).where(Permission.name == perm_name))
        perm = perm.scalar_one_or_none()
        if perm:
            db.add(CompanyMemberPermission(
                member_id=member_id,
                permission_id=perm.id,
                granted_by=current_user.id
            ))
    await db.commit()
    return {"detail": "Permissions updated"}

@router.get("/company/{company_id}/my")
async def my_permissions(
    company_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    member = await db.execute(
        select(CompanyMember).where(CompanyMember.company_id == company_id, CompanyMember.user_id == current_user.id)
    )
    member = member.scalar_one_or_none()
    if not member:
        raise HTTPException(status_code=404, detail="Not a member of this company")
    perms = await db.execute(
        select(Permission.name)
        .join(CompanyMemberPermission)
        .where(CompanyMemberPermission.member_id == member.id)
    )
    return {"permissions": [row[0] for row in perms.all()]}