from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.deps import get_current_user, get_session, require_roles
from app.core.permissions import Role
from app.models.permission_grant import UserPermissionGrant
from app.models.user import User
from app.schemas.permission_grant import PermissionGrantCreate, PermissionGrantRead
from app.schemas.user import UserCreate, UserRead
from app.services.auth_service import create_user
from app.services.permission_service import grant_permission, revoke_permission

router = APIRouter(prefix="/api/users", tags=["users"])


@router.post("", response_model=UserRead, status_code=status.HTTP_201_CREATED)
async def create_user_endpoint(
    payload: UserCreate,
    session: AsyncSession = Depends(get_session),
    _admin: User = Depends(require_roles(Role.ADMIN)),
) -> UserRead:
    """FR-1.3 — chỉ ADMIN tạo tài khoản mới."""
    user = await create_user(
        session,
        email=payload.email,
        password=payload.password,
        role=payload.role,
        department_id=payload.department_id,
    )
    return UserRead(id=user.id, email=user.email, role=user.role, department_id=user.department_id)


@router.get("/{user_id}/permissions", response_model=list[PermissionGrantRead])
async def list_permissions(
    user_id: UUID,
    session: AsyncSession = Depends(get_session),
    _actor: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> list[UserPermissionGrant]:
    result = await session.exec(select(UserPermissionGrant).where(UserPermissionGrant.user_id == user_id))
    return list(result.all())


@router.post(
    "/{user_id}/permissions",
    response_model=PermissionGrantRead,
    status_code=status.HTTP_201_CREATED,
)
async def create_permission(
    user_id: UUID,
    payload: PermissionGrantCreate,
    session: AsyncSession = Depends(get_session),
    actor: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> UserPermissionGrant:
    """FR-1.7/1.8 — chỉ ADMIN/Giám đốc cấp quyền bổ sung."""
    return await grant_permission(
        session,
        user_id=user_id,
        permission_group=payload.permission_group,
        scope=payload.scope.model_dump(mode="json"),
        granted_by_id=actor.id,
        expires_at=payload.expires_at,
    )


@router.delete("/{user_id}/permissions/{grant_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_permission(
    user_id: UUID,
    grant_id: UUID,
    session: AsyncSession = Depends(get_session),
    _actor: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> None:
    """FR-1.8 — thu hồi quyền bổ sung bất kỳ lúc nào."""
    grant = await session.get(UserPermissionGrant, grant_id)
    if grant is None or grant.user_id != user_id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Grant not found")
    await revoke_permission(session, grant)
