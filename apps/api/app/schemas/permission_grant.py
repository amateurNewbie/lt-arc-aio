from datetime import datetime
from uuid import UUID

from sqlmodel import SQLModel

from app.core.permissions import PermissionGroup
from app.models.enums import GrantScopeType


class GrantScope(SQLModel):
    type: GrantScopeType
    project_ids: list[UUID] | None = None


class PermissionGrantCreate(SQLModel):
    permission_group: PermissionGroup
    scope: GrantScope
    expires_at: datetime | None = None


class PermissionGrantRead(SQLModel):
    id: UUID
    user_id: UUID
    permission_group: PermissionGroup
    scope: dict
    granted_by_id: UUID
    granted_at: datetime
    expires_at: datetime | None
    revoked_at: datetime | None
