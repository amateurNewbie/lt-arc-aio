from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import JSON, Column
from sqlmodel import Field, SQLModel

from app.core.clock import utcnow
from app.core.permissions import PermissionGroup


class UserPermissionGrant(SQLModel, table=True):
    """FR-1.7/1.8 — quyền bổ sung cấp theo từng người dùng, ngoài quyền vai trò.

    `scope` là JSON: {"type": "ALL"} hoặc {"type": "PROJECTS", "project_ids": [...]}.
    """

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    user_id: UUID = Field(foreign_key="user.id", index=True)
    permission_group: PermissionGroup = Field(index=True)
    scope: dict = Field(sa_column=Column(JSON))

    granted_by_id: UUID = Field(foreign_key="user.id")
    granted_at: datetime = Field(default_factory=utcnow)
    expires_at: datetime | None = Field(default=None)
    revoked_at: datetime | None = Field(default=None)
