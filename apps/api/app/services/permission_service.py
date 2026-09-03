from datetime import datetime
from uuid import UUID

from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.clock import utcnow
from app.core.permissions import PermissionGroup, Role, role_has_default_grant
from app.models.enums import GrantScopeType
from app.models.permission_grant import UserPermissionGrant
from app.models.user import User


async def has_permission(
    session: AsyncSession,
    user: User,
    group: PermissionGroup,
    project_id: UUID | None = None,
) -> bool:
    """FR-1.7 — effective = defaults(role) ∪ grants(user) còn hiệu lực."""
    if role_has_default_grant(user.role, group):
        return True

    now = utcnow()
    result = await session.exec(
        select(UserPermissionGrant).where(
            UserPermissionGrant.user_id == user.id,
            UserPermissionGrant.permission_group == group,
            UserPermissionGrant.revoked_at.is_(None),
        )
    )
    for grant in result.all():
        if grant.expires_at is not None and grant.expires_at <= now:
            continue
        if grant.scope.get("type") == GrantScopeType.ALL:
            return True
        if project_id is not None and str(project_id) in (grant.scope.get("project_ids") or []):
            return True
    return False


async def grant_permission(
    session: AsyncSession,
    *,
    user_id: UUID,
    permission_group: PermissionGroup,
    scope: dict,
    granted_by_id: UUID,
    expires_at: datetime | None,
) -> UserPermissionGrant:
    grant = UserPermissionGrant(
        user_id=user_id,
        permission_group=permission_group,
        scope=scope,
        granted_by_id=granted_by_id,
        expires_at=expires_at,
    )
    session.add(grant)
    await session.commit()
    await session.refresh(grant)
    return grant


async def revoke_permission(session: AsyncSession, grant: UserPermissionGrant) -> UserPermissionGrant:
    grant.revoked_at = utcnow()
    session.add(grant)
    await session.commit()
    await session.refresh(grant)
    return grant
