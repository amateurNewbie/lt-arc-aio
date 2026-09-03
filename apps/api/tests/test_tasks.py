from datetime import date

from httpx import AsyncClient
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.permissions import Role
from app.core.security import create_access_token
from app.models.enums import ProjectCategory, TaskStatus
from app.services.auth_service import create_user
from app.services.department_service import create_department
from app.services.project_service import create_project
from app.services.task_service import IncompleteSubtasksError, create_task, update_progress


def _auth_headers(user) -> dict:
    return {"Authorization": f"Bearer {create_access_token(user.id)}"}


async def _make_project(session: AsyncSession, director) -> tuple:
    dept = await create_department(session, name="Thi công", head_user_id=None)
    project = await create_project(
        session,
        name="Biệt thự An Phú",
        client="Anh Tuấn",
        category=ProjectCategory.CONSTRUCTION,
        manager_id=director.id,
        actor=director,
    )
    return dept, project


async def test_subtask_blocks_parent_auto_complete(session: AsyncSession) -> None:
    """FR-5.2 — công việc cha không tự chuyển 'Đã hoàn thành' khi còn đầu việc con chưa xong."""
    director = await create_user(session, email="dtask1@ltarc.vn", password="x", role=Role.DIRECTOR)
    dept, project = await _make_project(session, director)

    parent = await create_task(session, title="Thi công phần thô", project_id=project.id, department_id=dept.id)
    child = await create_task(
        session, title="Đổ móng", project_id=project.id, department_id=dept.id, parent_task_id=parent.id
    )

    try:
        await update_progress(session, parent, progress=100)
        assert False, "expected IncompleteSubtasksError"
    except IncompleteSubtasksError:
        pass

    child = await update_progress(session, child, progress=100)
    assert child.status == TaskStatus.DONE

    parent = await update_progress(session, parent, progress=100)
    assert parent.status == TaskStatus.DONE


async def test_employee_can_only_update_own_task(client: AsyncClient, session: AsyncSession) -> None:
    director = await create_user(session, email="dtask2@ltarc.vn", password="x", role=Role.DIRECTOR)
    dept, project = await _make_project(session, director)

    employee_a = await create_user(session, email="empa@ltarc.vn", password="x", role=Role.EMPLOYEE, department_id=dept.id)
    employee_b = await create_user(session, email="empb@ltarc.vn", password="x", role=Role.EMPLOYEE, department_id=dept.id)

    task = await create_task(
        session,
        title="Lắp đặt điện tầng 2",
        project_id=project.id,
        department_id=dept.id,
        assignee_id=employee_a.id,
    )

    resp = await client.patch(
        f"/api/tasks/{task.id}", headers=_auth_headers(employee_b), json={"progress": 50}
    )
    assert resp.status_code == 403

    resp = await client.patch(
        f"/api/tasks/{task.id}", headers=_auth_headers(employee_a), json={"progress": 50}
    )
    assert resp.status_code == 200
    assert resp.json()["progress"] == 50


async def test_department_head_cannot_create_task_outside_own_department(
    client: AsyncClient, session: AsyncSession
) -> None:
    director = await create_user(session, email="dtask3@ltarc.vn", password="x", role=Role.DIRECTOR)
    own_dept, project = await _make_project(session, director)
    other_dept = await create_department(session, name="Thiết kế", head_user_id=None)

    head = await create_user(
        session, email="head3@ltarc.vn", password="x", role=Role.DEPARTMENT_HEAD, department_id=own_dept.id
    )

    resp = await client.post(
        "/api/tasks",
        headers=_auth_headers(head),
        json={"title": "Việc ngoài bộ phận", "project_id": str(project.id), "department_id": str(other_dept.id)},
    )
    assert resp.status_code == 403

    resp = await client.post(
        "/api/tasks",
        headers=_auth_headers(head),
        json={"title": "Việc trong bộ phận", "project_id": str(project.id), "department_id": str(own_dept.id)},
    )
    assert resp.status_code == 201


async def test_overdue_flag_set_when_due_date_passed(client: AsyncClient, session: AsyncSession) -> None:
    """FR-5.6 — cảnh báo công việc quá hạn."""
    director = await create_user(session, email="dtask4@ltarc.vn", password="x", role=Role.DIRECTOR)
    dept, project = await _make_project(session, director)

    await create_task(
        session,
        title="Việc quá hạn",
        project_id=project.id,
        department_id=dept.id,
        due_date=date(2020, 1, 1),
    )

    resp = await client.get("/api/tasks", headers=_auth_headers(director))
    assert resp.status_code == 200
    assert any(t["is_overdue"] for t in resp.json())
