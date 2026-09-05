from datetime import timedelta

from httpx import AsyncClient
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.clock import utcnow
from app.core.permissions import Role
from app.core.security import create_access_token
from app.models.enums import ProjectCategory, TaskPriority
from app.services.auth_service import create_user
from app.services.department_service import create_department
from app.services.notification_service import run_daily_reminders
from app.services.project_service import create_project
from app.services.settings_service import update_company_settings
from app.services.task_service import create_task


def _auth_headers(user) -> dict:
    return {"Authorization": f"Bearer {create_access_token(user.id)}"}


async def test_file_upload_download_delete_round_trip(client: AsyncClient, session: AsyncSession) -> None:
    """FR-17.1/17.2/17.3 — tải lên, xem danh sách, tải xuống, xoá tệp gắn với dự án."""
    director = await create_user(session, email="file1@ltarc.vn", password="x", role=Role.DIRECTOR)
    project = await create_project(
        session, name="Nhà phố Test File", client="KH File", category=ProjectCategory.CONSTRUCTION, manager_id=director.id, actor=director
    )

    upload = await client.post(
        f"/api/files?project_id={project.id}",
        headers=_auth_headers(director),
        files={"file": ("hop_dong.txt", b"noi dung hop dong test", "text/plain")},
    )
    assert upload.status_code == 201
    asset = upload.json()
    assert asset["name"] == "hop_dong.txt"
    assert asset["size_bytes"] == len(b"noi dung hop dong test")

    listing = await client.get(f"/api/files?project_id={project.id}", headers=_auth_headers(director))
    assert listing.status_code == 200
    assert len(listing.json()) == 1

    download = await client.get(f"/api/files/{asset['id']}/download", headers=_auth_headers(director))
    assert download.status_code == 200
    assert download.content == b"noi dung hop dong test"

    delete = await client.delete(f"/api/files/{asset['id']}", headers=_auth_headers(director))
    assert delete.status_code == 204

    listing_after = await client.get(f"/api/files?project_id={project.id}", headers=_auth_headers(director))
    assert listing_after.json() == []


async def test_daily_reminders_notify_assignee_of_task_due_soon(session: AsyncSession) -> None:
    """FR-19.2 — nhắc công việc sắp đến hạn theo số ngày cấu hình trong CompanySettings."""
    director = await create_user(session, email="notif1@ltarc.vn", password="x", role=Role.DIRECTOR)
    employee = await create_user(session, email="empnotif1@ltarc.vn", password="x", role=Role.EMPLOYEE)
    dept = await create_department(session, name="Thi công Test Notif", head_user_id=None)
    project = await create_project(
        session, name="Villa Test Notif", client="KH Notif", category=ProjectCategory.CONSTRUCTION, manager_id=director.id, actor=director
    )

    await update_company_settings(session, {"task_reminder_days": 2})
    due_date = (utcnow() + timedelta(days=2)).date()

    await create_task(
        session,
        title="Nghiệm thu phần thô",
        project_id=project.id,
        department_id=dept.id,
        actor=director,
        due_date=due_date,
        priority=TaskPriority.HIGH,
        assignee_id=employee.id,
    )

    created = await run_daily_reminders(session)
    assert created >= 1

    from app.services.notification_service import list_for_user

    notifications = await list_for_user(session, employee)
    assert any("Nghiệm thu phần thô" in n.message for n in notifications)


async def test_notification_mark_read_forbidden_for_other_user(client: AsyncClient, session: AsyncSession) -> None:
    """FR-19.3 — người dùng chỉ đánh dấu được thông báo của chính mình."""
    from app.services.notification_service import create_notification

    user_a = await create_user(session, email="notifa@ltarc.vn", password="x", role=Role.EMPLOYEE)
    user_b = await create_user(session, email="notifb@ltarc.vn", password="x", role=Role.EMPLOYEE)
    notification = await create_notification(session, user_id=user_a.id, title="Test", message="Nội dung test")

    forbidden = await client.patch(f"/api/notifications/{notification.id}/read", headers=_auth_headers(user_b))
    assert forbidden.status_code == 403

    ok = await client.patch(f"/api/notifications/{notification.id}/read", headers=_auth_headers(user_a))
    assert ok.status_code == 200
    assert ok.json()["read"] is True
