from datetime import timedelta

import pytest
from httpx import AsyncClient
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.clock import utcnow
from app.core.permissions import PermissionGroup, Role
from app.services.auth_service import create_user
from app.services.permission_service import grant_permission, has_permission


@pytest.fixture
def _settings_lockout(monkeypatch: pytest.MonkeyPatch):
    """FR-1.4 dùng threshold=5, nhưng test này chỉ cần override để test nhanh."""
    from app.core.config import get_settings

    get_settings().failed_login_lockout_threshold = 3
    yield
    get_settings().failed_login_lockout_threshold = 5


async def test_login_success(client: AsyncClient, session: AsyncSession) -> None:
    await create_user(session, email="a@ltarc.vn", password="Secret123!", role=Role.EMPLOYEE)

    response = await client.post("/api/auth/login", json={"email": "a@ltarc.vn", "password": "Secret123!"})

    assert response.status_code == 200
    body = response.json()
    assert "access_token" in body and "refresh_token" in body


async def test_login_wrong_password_rejected(client: AsyncClient, session: AsyncSession) -> None:
    await create_user(session, email="b@ltarc.vn", password="Secret123!", role=Role.EMPLOYEE)

    response = await client.post("/api/auth/login", json={"email": "b@ltarc.vn", "password": "wrong"})

    assert response.status_code == 401


async def test_account_locks_after_threshold(client: AsyncClient, session: AsyncSession, _settings_lockout) -> None:
    """FR-1.4 — khoá tài khoản sau N lần sai liên tiếp (threshold override = 3 trong test)."""
    await create_user(session, email="c@ltarc.vn", password="Secret123!", role=Role.EMPLOYEE)

    for _ in range(3):
        resp = await client.post("/api/auth/login", json={"email": "c@ltarc.vn", "password": "wrong"})
        assert resp.status_code == 401

    # 4th attempt, even with the correct password, must be rejected as locked.
    resp = await client.post("/api/auth/login", json={"email": "c@ltarc.vn", "password": "Secret123!"})
    assert resp.status_code == 423


async def test_me_requires_token(client: AsyncClient) -> None:
    response = await client.get("/api/auth/me")
    assert response.status_code == 401


async def test_grant_permission_all_scope_grants_immediately(session: AsyncSession) -> None:
    admin = await create_user(session, email="admin2@ltarc.vn", password="x", role=Role.ADMIN)
    employee = await create_user(session, email="d@ltarc.vn", password="x", role=Role.EMPLOYEE)

    assert not await has_permission(session, employee, PermissionGroup.FUNDS)

    await grant_permission(
        session,
        user_id=employee.id,
        permission_group=PermissionGroup.FUNDS,
        scope={"type": "ALL"},
        granted_by_id=admin.id,
        expires_at=None,
    )

    assert await has_permission(session, employee, PermissionGroup.FUNDS)


async def test_grant_permission_expired_is_ignored(session: AsyncSession) -> None:
    """FR-1.8 — quyền hết thời hạn tự động vô hiệu."""
    admin = await create_user(session, email="admin3@ltarc.vn", password="x", role=Role.ADMIN)
    employee = await create_user(session, email="e@ltarc.vn", password="x", role=Role.EMPLOYEE)

    await grant_permission(
        session,
        user_id=employee.id,
        permission_group=PermissionGroup.WORKDAYS_ENTRY,
        scope={"type": "ALL"},
        granted_by_id=admin.id,
        expires_at=utcnow() - timedelta(days=1),
    )

    assert not await has_permission(session, employee, PermissionGroup.WORKDAYS_ENTRY)
