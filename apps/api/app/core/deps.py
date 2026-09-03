from collections.abc import AsyncGenerator
from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.permissions import PermissionGroup, Role
from app.core.security import TokenError, decode_token
from app.db.session import async_session_factory
from app.models.user import User
from app.services.permission_service import has_permission

bearer_scheme = HTTPBearer(auto_error=False)


async def get_session() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_factory() as session:
        yield session


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    session: AsyncSession = Depends(get_session),
) -> User:
    """FR-1.2 — từ chối truy cập nếu không có token hợp lệ."""
    if credentials is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Missing bearer token")

    try:
        user_id: UUID = decode_token(credentials.credentials, expected_type="access")
    except TokenError as exc:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, str(exc)) from exc

    user = await session.get(User, user_id)
    if user is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "User no longer exists")
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
