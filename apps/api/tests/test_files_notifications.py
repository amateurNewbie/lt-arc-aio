from datetime import timedelta

from httpx import AsyncClient
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.clock import utcnow
from app.core.permissions import Role
from app.core.security import create_access_token
from app.models.enums import LeadStatus, ProjectCategory, TaskPriority
from app.services.auth_service import create_user
from app.services.department_service import create_department
from app.services.lead_service import create_lead, update_lead_status
from app.services.notification_service import list_for_user, run_daily_reminders
from app.services.project_service import create_project
from app.services.settings_service import update_company_settings
from app.services.task_service import create_task
from app.services.work_item_service import create_work_item


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
    work_item = await create_work_item(
        session,
        project_id=project.id,
        department_id=dept.id,
        name="Hạng mục nghiệm thu",
        actor=director,
        create_linked_task=False,
    )

    await create_task(
        session,
        title="Nghiệm thu phần thô",
        project_id=project.id,
        department_id=dept.id,
        work_item_id=work_item.id,
        actor=director,
        due_date=due_date,
        priority=TaskPriority.HIGH,
        assignee_id=employee.id,
    )

    created = await run_daily_reminders(session)
    assert created >= 1

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


async def test_register_and_unregister_device_token(client: AsyncClient, session: AsyncSession) -> None:
    """Đăng ký token FCM, refresh token đã tồn tại (upsert), rồi huỷ đăng ký khi logout."""
    from sqlmodel import select

    from app.models.device_token import DeviceToken

    user = await create_user(session, email="device1@ltarc.vn", password="x", role=Role.EMPLOYEE)
    other = await create_user(session, email="device2@ltarc.vn", password="x", role=Role.EMPLOYEE)

    register = await client.post(
        "/api/notifications/devices",
        headers=_auth_headers(user),
        json={"fcm_token": "token-abc", "platform": "ANDROID"},
    )
    assert register.status_code == 201
    assert register.json()["platform"] == "ANDROID"

    # Đăng ký lại cùng token (refresh) không tạo trùng bản ghi.
    refresh = await client.post(
        "/api/notifications/devices",
        headers=_auth_headers(user),
        json={"fcm_token": "token-abc", "platform": "ANDROID"},
    )
    assert refresh.status_code == 201
    assert refresh.json()["id"] == register.json()["id"]

    # User khác không xoá được token không thuộc về mình (idempotent no-op).
    forbidden_delete = await client.delete("/api/notifications/devices/token-abc", headers=_auth_headers(other))
    assert forbidden_delete.status_code == 204
    still_there = (await session.exec(select(DeviceToken).where(DeviceToken.fcm_token == "token-abc"))).first()
    assert still_there is not None

    ok_delete = await client.delete("/api/notifications/devices/token-abc", headers=_auth_headers(user))
    assert ok_delete.status_code == 204
    gone = (await session.exec(select(DeviceToken).where(DeviceToken.fcm_token == "token-abc"))).first()
    assert gone is None


async def test_task_assignment_notifies_assignee_immediately(session: AsyncSession) -> None:
    """Phase 2 — giao việc cho người khác phải bắn thông báo real-time ngay, không đợi batch 01:00."""
    director = await create_user(session, email="assign1@ltarc.vn", password="x", role=Role.DIRECTOR)
    employee = await create_user(session, email="assignee1@ltarc.vn", password="x", role=Role.EMPLOYEE)
    dept = await create_department(session, name="Thi công Test Assign", head_user_id=None)
    project = await create_project(
        session, name="Villa Test Assign", client="KH Assign", category=ProjectCategory.CONSTRUCTION, manager_id=director.id, actor=director
    )
    work_item = await create_work_item(
        session, project_id=project.id, department_id=dept.id, name="Hạng mục", actor=director, create_linked_task=False
    )

    await create_task(
        session,
        title="Lắp đặt hệ thống điện",
        project_id=project.id,
        department_id=dept.id,
        work_item_id=work_item.id,
        actor=director,
        priority=TaskPriority.MEDIUM,
        assignee_id=employee.id,
    )

    notifications = await list_for_user(session, employee)
    assert any(n.kind == "TASK_ASSIGNED" and n.entity_type == "task" for n in notifications)

    # Tự giao việc cho chính mình thì không cần tự thông báo.
    self_assign_notifications_before = len(await list_for_user(session, director))
    await create_task(
        session,
        title="Việc tự làm",
        project_id=project.id,
        department_id=dept.id,
        work_item_id=work_item.id,
        actor=director,
        priority=TaskPriority.LOW,
        assignee_id=director.id,
    )
    assert len(await list_for_user(session, director)) == self_assign_notifications_before


async def test_lead_status_change_notifies_owner_but_not_self(session: AsyncSession) -> None:
    """Phase 2 — đổi trạng thái lead bởi người khác (vd. Admin) phải báo cho owner; owner tự đổi thì không tự báo."""
    admin = await create_user(session, email="admin1@ltarc.vn", password="x", role=Role.ADMIN)
    owner = await create_user(session, email="owner1@ltarc.vn", password="x", role=Role.EMPLOYEE)

    lead = await create_lead(session, name="Chị Lan Anh", owner_id=owner.id)
    await update_lead_status(session, lead, status=LeadStatus.CONSULTING, actor=admin)

    notifications = await list_for_user(session, owner)
    assert any(n.kind == "LEAD_STATUS_CHANGED" and n.entity_type == "lead" and n.entity_id == lead.id for n in notifications)

    before = len(await list_for_user(session, owner))
    await update_lead_status(session, lead, status=LeadStatus.QUOTED, actor=owner)
    assert len(await list_for_user(session, owner)) == before
