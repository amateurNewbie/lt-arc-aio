from collections.abc import AsyncGenerator
from uuid import UUID

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.permissions import PermissionGroup, Role
from app.core.security import TokenError, decode_token_payload
from app.db.session import async_session_factory
from app.models.project import ProjectDepartmentHead
from app.models.user import User
from app.services.permission_service import has_permission

bearer_scheme = HTTPBearer(auto_error=False)


async def get_session() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_factory() as session:
        yield session


async def get_current_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    session: AsyncSession = Depends(get_session),
) -> User:
    """FR-1.2 — từ chối truy cập nếu không có token hợp lệ.

    FR-1.6 — token mang claim `preview_role` chỉ được phép GET (xem thử,
    không sửa dữ liệu); vai trò hiệu lực trong request được ghi đè tạm thời
    trên đối tượng `User` trong bộ nhớ (không commit) để toàn bộ các kiểm tra
    `require_roles`/`require_perm` sẵn có tự động áp dụng đúng vai trò xem thử.
    """
    if credentials is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Missing bearer token")

    try:
        payload = decode_token_payload(credentials.credentials, expected_type="access")
        user_id = UUID(payload["sub"])
    except (TokenError, KeyError, ValueError) as exc:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid or expired token") from exc

    user = await session.get(User, user_id)
    if user is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "User no longer exists")

    preview_role = payload.get("preview_role")
    if preview_role:
        if request.method != "GET":
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Preview mode is read-only")
        user.role = Role(preview_role)

    return user


def require_roles(*roles: Role):
    """FR-1.3 và các ràng buộc vai trò tương tự (ví dụ chỉ ADMIN tạo user)."""

    async def dependency(user: User = Depends(get_current_user)) -> User:
        if user.role not in roles:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Insufficient role")
        return user

    return dependency


def require_perm(group: PermissionGroup, project_id: UUID | None = None):
    """FR-1.7 — quyền hiệu lực = quyền vai trò ∪ quyền được cấp thêm còn hạn."""

    async def dependency(
        user: User = Depends(get_current_user),
        session: AsyncSession = Depends(get_session),
    ) -> User:
        allowed = await has_permission(session, user, group, project_id)
        if not allowed:
            raise HTTPException(status.HTTP_403_FORBIDDEN, f"Missing permission group {group}")
        return user

    return dependency


def require_project_finance_write(group: PermissionGroup):
    """FR-6.5/RBAC §2.6 — Khai báo chi phí dự án: Admin/Giám đốc toàn quyền,
    Trưởng bộ phận được mặc định trên (các) dự án mình phụ trách (FR-3.5),
    người khác cần được cấp quyền bổ sung (FR-1.7)."""

    async def dependency(
        project_id: UUID,
        user: User = Depends(get_current_user),
        session: AsyncSession = Depends(get_session),
    ) -> User:
        if await has_permission(session, user, group, project_id):
            return user

        if user.role == Role.DEPARTMENT_HEAD:
            result = await session.exec(
                select(ProjectDepartmentHead).where(
                    ProjectDepartmentHead.project_id == project_id,
                    ProjectDepartmentHead.user_id == user.id,
                )
            )
            if result.first() is not None:
                return user

        raise HTTPException(status.HTTP_403_FORBIDDEN, f"Missing permission group {group}")

    return dependency
