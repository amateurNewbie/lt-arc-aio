from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.permissions import (
    PermissionGroup,
    Role,
    ROLES_WITH_ALL_GRANTS_BY_DEFAULT,
)
from app.models.role_permission import RolePermissionDefault
from app.schemas.role_permission import RolePermissionEntry


async def ensure_role_permission_defaults(session: AsyncSession) -> None:
    """Đảm bảo đủ 4×6 dòng — seed theo rule cứng hiện tại nếu thiếu."""
    existing = await session.exec(select(RolePermissionDefault))
    present = {(Role(r.role), PermissionGroup(r.permission_group)) for r in existing.all()}
    missing = False
    for role in Role:
        for group in PermissionGroup:
            if (role, group) in present:
                continue
            session.add(
                RolePermissionDefault(
                    role=role,
                    permission_group=group,
                    enabled=role in ROLES_WITH_ALL_GRANTS_BY_DEFAULT,
                )
            )
            missing = True
    if missing:
        await session.commit()


async def list_role_permission_matrix(session: AsyncSession) -> list[RolePermissionEntry]:
    await ensure_role_permission_defaults(session)
    result = await session.exec(select(RolePermissionDefault))
    rows = list(result.all())

    def _role(r: RolePermissionDefault) -> Role:
        return r.role if isinstance(r.role, Role) else Role(r.role)

    def _group(r: RolePermissionDefault) -> PermissionGroup:
        return r.permission_group if isinstance(r.permission_group, PermissionGroup) else PermissionGroup(r.permission_group)

    rows.sort(key=lambda r: (list(Role).index(_role(r)), list(PermissionGroup).index(_group(r))))
    return [
        RolePermissionEntry(role=_role(r), permission_group=_group(r), enabled=r.enabled)
        for r in rows
    ]


async def update_role_permission_matrix(
    session: AsyncSession,
    entries: list[RolePermissionEntry],
) -> list[RolePermissionEntry]:
    """Upsert toàn bộ ma trận — chỉ ADMIN/DIRECTOR gọi (kiểm tra ở router)."""
    await ensure_role_permission_defaults(session)

    expected = {(role, group) for role in Role for group in PermissionGroup}
    provided = {(e.role, e.permission_group) for e in entries}
    if provided != expected:
        raise ValueError("Matrix must include every role × permission group exactly once")

    by_key = {(e.role, e.permission_group): e.enabled for e in entries}
    result = await session.exec(select(RolePermissionDefault))
    for row in result.all():
        role = row.role if isinstance(row.role, Role) else Role(row.role)
        group = (
            row.permission_group
            if isinstance(row.permission_group, PermissionGroup)
            else PermissionGroup(row.permission_group)
        )
        row.enabled = by_key[(role, group)]
        session.add(row)

    await session.commit()
    return await list_role_permission_matrix(session)


async def role_has_default_grant(
    session: AsyncSession,
    role: Role,
    group: PermissionGroup,
) -> bool:
    """Đọc quyền mặc định từ DB; fallback cứng nếu chưa seed."""
    result = await session.exec(
        select(RolePermissionDefault).where(
            RolePermissionDefault.role == role.value,
            RolePermissionDefault.permission_group == group.value,
        )
    )
    row = result.first()
    if row is None:
        return role in ROLES_WITH_ALL_GRANTS_BY_DEFAULT
    return row.enabled
