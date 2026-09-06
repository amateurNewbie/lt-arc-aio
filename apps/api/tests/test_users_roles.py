import pytest
from httpx import AsyncClient
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.permissions import PermissionGroup, Role
from app.core.security import create_access_token
from app.services.auth_service import create_user
from app.services.permission_service import has_permission
from app.services.role_permission_service import list_role_permission_matrix, update_role_permission_matrix
from app.schemas.role_permission import RolePermissionEntry


def _auth(user) -> dict[str, str]:
    return {"Authorization": f"Bearer {create_access_token(user.id)}"}


async def test_director_can_create_user(client: AsyncClient, session: AsyncSession) -> None:
    director = await create_user(session, email="dir-create@ltarc.vn", password="x", role=Role.DIRECTOR)

    response = await client.post(
        "/api/users",
        headers=_auth(director),
        json={
            "email": "new-staff@ltarc.vn",
            "password": "Secret123!",
            "role": "EMPLOYEE",
            "full_name": "Nhân viên mới",
        },
    )

    assert response.status_code == 201
    body = response.json()
    assert body["email"] == "new-staff@ltarc.vn"
    assert body["role"] == "EMPLOYEE"


async def test_employee_cannot_create_user(client: AsyncClient, session: AsyncSession) -> None:
    employee = await create_user(session, email="emp-create@ltarc.vn", password="x", role=Role.EMPLOYEE)

    response = await client.post(
        "/api/users",
        headers=_auth(employee),
        json={"email": "x@ltarc.vn", "password": "Secret123!", "role": "EMPLOYEE"},
    )

    assert response.status_code == 403


async def test_department_head_cannot_create_user(client: AsyncClient, session: AsyncSession) -> None:
    head = await create_user(session, email="head-create@ltarc.vn", password="x", role=Role.DEPARTMENT_HEAD)

    response = await client.post(
        "/api/users",
        headers=_auth(head),
        json={"email": "y@ltarc.vn", "password": "Secret123!", "role": "EMPLOYEE"},
    )

    assert response.status_code == 403


async def test_role_permission_matrix_get_put(client: AsyncClient, session: AsyncSession) -> None:
    admin = await create_user(session, email="role-admin@ltarc.vn", password="x", role=Role.ADMIN)

    get_resp = await client.get("/api/roles/permissions", headers=_auth(admin))
    assert get_resp.status_code == 200
    entries = get_resp.json()["entries"]
    assert len(entries) == 24

    # Bật WORKDAYS_ENTRY cho EMPLOYEE
    updated = []
    for e in entries:
        enabled = e["enabled"]
        if e["role"] == "EMPLOYEE" and e["permission_group"] == "WORKDAYS_ENTRY":
            enabled = True
        updated.append({**e, "enabled": enabled})

    put_resp = await client.put("/api/roles/permissions", headers=_auth(admin), json={"entries": updated})
    assert put_resp.status_code == 200

    employee = await create_user(session, email="role-emp@ltarc.vn", password="x", role=Role.EMPLOYEE)
    assert await has_permission(session, employee, PermissionGroup.WORKDAYS_ENTRY)
    assert not await has_permission(session, employee, PermissionGroup.FUNDS)


async def test_employee_cannot_edit_role_permissions(client: AsyncClient, session: AsyncSession) -> None:
    employee = await create_user(session, email="role-emp2@ltarc.vn", password="x", role=Role.EMPLOYEE)
    response = await client.get("/api/roles/permissions", headers=_auth(employee))
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_update_matrix_incomplete_raises(session: AsyncSession) -> None:
    await list_role_permission_matrix(session)
    with pytest.raises(ValueError):
        await update_role_permission_matrix(
            session,
            [RolePermissionEntry(role=Role.ADMIN, permission_group=PermissionGroup.FUNDS, enabled=True)],
        )
