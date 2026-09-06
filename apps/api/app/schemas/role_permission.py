from sqlmodel import SQLModel

from app.core.permissions import PermissionGroup, Role


class RolePermissionEntry(SQLModel):
    role: Role
    permission_group: PermissionGroup
    enabled: bool


class RolePermissionMatrixRead(SQLModel):
    entries: list[RolePermissionEntry]


class RolePermissionMatrixUpdate(SQLModel):
    """Gửi đủ 4 role × 6 nhóm (24 dòng) — server upsert toàn bộ."""

    entries: list[RolePermissionEntry]
