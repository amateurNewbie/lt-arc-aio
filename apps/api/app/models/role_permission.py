from sqlmodel import Field, SQLModel

from app.core.permissions import PermissionGroup, Role


class RolePermissionDefault(SQLModel, table=True):
    """Quyền mặc định theo vai trò (6 nhóm FR-1.7) — Admin/Giám đốc chỉnh qua UI.

    Composite PK `(role, permission_group)`. Khi chưa có dòng (DB mới / test),
    `permission_service` fallback cứng: ADMIN/DIRECTOR = bật hết.
    """

    role: Role = Field(primary_key=True)
    permission_group: PermissionGroup = Field(primary_key=True)
    enabled: bool = Field(default=False)
