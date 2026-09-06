from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.deps import get_session, require_roles
from app.core.permissions import Role
from app.models.user import User
from app.schemas.role_permission import RolePermissionMatrixRead, RolePermissionMatrixUpdate
from app.services.role_permission_service import list_role_permission_matrix, update_role_permission_matrix

router = APIRouter(prefix="/api/roles", tags=["roles"])


@router.get("/permissions", response_model=RolePermissionMatrixRead)
async def get_role_permissions(
    session: AsyncSession = Depends(get_session),
    _actor: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> RolePermissionMatrixRead:
    """Ma trận quyền mặc định 4 role × 6 nhóm — chỉ Admin/Giám đốc."""
    entries = await list_role_permission_matrix(session)
    return RolePermissionMatrixRead(entries=entries)


@router.put("/permissions", response_model=RolePermissionMatrixRead)
async def put_role_permissions(
    payload: RolePermissionMatrixUpdate,
    session: AsyncSession = Depends(get_session),
    _actor: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> RolePermissionMatrixRead:
    """Cập nhật quyền mặc định theo vai trò — chỉ Admin/Giám đốc."""
    try:
        entries = await update_role_permission_matrix(session, payload.entries)
    except ValueError as exc:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, str(exc)) from exc
    return RolePermissionMatrixRead(entries=entries)
