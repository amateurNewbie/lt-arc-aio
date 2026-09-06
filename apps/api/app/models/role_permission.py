from sqlalchemy import Boolean, Column, String
from sqlmodel import Field, SQLModel

from app.core.permissions import PermissionGroup, Role


class RolePermissionDefault(SQLModel, table=True):
    """Quyền mặc định theo vai trò (6 nhóm FR-1.7) — Admin/Giám đốc chỉnh qua UI.

    Composite PK `(role, permission_group)`. Cột DB là VARCHAR (migration 0010),
    không dùng Postgres ENUM — tránh lỗi `varchar = role` khi query.
    """

    role: Role = Field(sa_column=Column(String, primary_key=True))
    permission_group: PermissionGroup = Field(sa_column=Column(String, primary_key=True))
    enabled: bool = Field(default=False, sa_column=Column(Boolean, nullable=False, server_default="false"))
