from httpx import AsyncClient
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.permissions import Role
from app.core.security import create_access_token
from app.models.enums import LeadStatus, ProjectCategory
from app.services.auth_service import create_user
from app.services.lead_service import (
    InvalidLeadStatusTransitionError,
    LeadAlreadyConvertedError,
    convert_to_project,
    create_lead,
    update_lead_status,
)


def _auth_headers(user) -> dict:
    return {"Authorization": f"Bearer {create_access_token(user.id)}"}


async def test_create_and_list_lead(client: AsyncClient, session: AsyncSession) -> None:
    director = await create_user(session, email="d1@ltarc.vn", password="x", role=Role.DIRECTOR)

    resp = await client.post(
        "/api/leads",
        headers=_auth_headers(director),
        json={"name": "Anh Hoàng Minh", "phone": "0911222333", "need": "Nhà phố 4 tầng"},
    )
    assert resp.status_code == 201
    assert resp.json()["status"] == "NEW"
    assert resp.json()["owner_id"] == str(director.id)

    resp = await client.get("/api/leads", headers=_auth_headers(director))
    assert resp.status_code == 200
    assert len(resp.json()) == 1


async def test_employee_sees_only_own_leads(client: AsyncClient, session: AsyncSession) -> None:
    """FR-2.4 — Nhân viên xem được khách hàng tiềm năng mình phụ trách, không thấy của người khác."""
    employee = await create_user(session, email="emp1@ltarc.vn", password="x", role=Role.EMPLOYEE)
    other = await create_user(session, email="emp2@ltarc.vn", password="x", role=Role.EMPLOYEE)

    await create_lead(session, name="Lead của tôi", owner_id=employee.id)
    await create_lead(session, name="Lead của người khác", owner_id=other.id)

    resp = await client.get("/api/leads", headers=_auth_headers(employee))
    assert resp.status_code == 200
    names = [item["name"] for item in resp.json()]
    assert names == ["Lead của tôi"]


async def test_admin_sees_all_leads(client: AsyncClient, session: AsyncSession) -> None:
    admin = await create_user(session, email="admin1@ltarc.vn", password="x", role=Role.ADMIN)
    employee = await create_user(session, email="emp3@ltarc.vn", password="x", role=Role.EMPLOYEE)

    await create_lead(session, name="Lead A", owner_id=admin.id)
    await create_lead(session, name="Lead B", owner_id=employee.id)

    resp = await client.get("/api/leads", headers=_auth_headers(admin))
    assert resp.status_code == 200
    assert len(resp.json()) == 2


async def test_convert_lead_creates_project_and_links_back(session: AsyncSession) -> None:
    """FR-2.3 — chốt lead tạo dự án mới, giữ liên kết ngược."""
    director = await create_user(session, email="d2@ltarc.vn", password="x", role=Role.DIRECTOR)
    lead = await create_lead(session, name="Anh Quang Huy", owner_id=director.id, budget_estimate=450_000_000)

    lead, project = await convert_to_project(
        session,
        lead,
        actor=director,
        category=ProjectCategory.DESIGN,
        manager_id=director.id,
    )

    assert lead.status == LeadStatus.CONVERTED
    assert lead.converted_project_id == project.id
    assert project.lead_id == lead.id
    assert project.budget == 450_000_000  # kế thừa từ budget_estimate khi không truyền budget riêng
    assert project.code.startswith("LT-")


async def test_convert_already_converted_lead_raises(session: AsyncSession) -> None:
    director = await create_user(session, email="d3@ltarc.vn", password="x", role=Role.DIRECTOR)
    lead = await create_lead(session, name="Chị Kim Ngân", owner_id=director.id)
    lead, _project = await convert_to_project(
        session, lead, actor=director, category=ProjectCategory.CONSTRUCTION, manager_id=director.id
    )

    try:
        await convert_to_project(
            session, lead, actor=director, category=ProjectCategory.CONSTRUCTION, manager_id=director.id
        )
        assert False, "expected LeadAlreadyConvertedError"
    except LeadAlreadyConvertedError:
        pass


async def test_lead_status_transition_rejects_skipped_step(session: AsyncSession) -> None:
    """FR-2.2 — không được nhảy vượt bước (NEW -> QUOTED thẳng là sai)."""
    director = await create_user(session, email="d4@ltarc.vn", password="x", role=Role.DIRECTOR)
    lead = await create_lead(session, name="Anh Văn Đức", owner_id=director.id)

    try:
        await update_lead_status(session, lead, status=LeadStatus.QUOTED, actor=director)
        assert False, "expected InvalidLeadStatusTransitionError"
    except InvalidLeadStatusTransitionError:
        pass


async def test_lead_status_transition_writes_history_with_note(client: AsyncClient, session: AsyncSession) -> None:
    director = await create_user(session, email="d5@ltarc.vn", password="x", role=Role.DIRECTOR)
    lead = await create_lead(session, name="Chị Ngọc Lan", owner_id=director.id)

    resp = await client.patch(
        f"/api/leads/{lead.id}",
        headers=_auth_headers(director),
        json={"status": "CONSULTING", "note": "Đã gọi tư vấn lần 1"},
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "CONSULTING"

    from sqlmodel import select

    from app.models.lead_status_history import LeadStatusHistory

    result = await session.exec(select(LeadStatusHistory).where(LeadStatusHistory.lead_id == lead.id))
    history = result.all()
    assert len(history) == 1
    assert history[0].from_status == LeadStatus.NEW
    assert history[0].to_status == LeadStatus.CONSULTING
    assert history[0].note == "Đã gọi tư vấn lần 1"
    assert history[0].actor_id == director.id


async def test_employee_cannot_edit_others_lead(client: AsyncClient, session: AsyncSession) -> None:
    owner = await create_user(session, email="emp4@ltarc.vn", password="x", role=Role.EMPLOYEE)
    other = await create_user(session, email="emp5@ltarc.vn", password="x", role=Role.EMPLOYEE)
    lead = await create_lead(session, name="Lead của owner", owner_id=owner.id)

    resp = await client.patch(
        f"/api/leads/{lead.id}",
        headers=_auth_headers(other),
        json={"status": "CONSULTING"},
    )
    assert resp.status_code == 403


async def test_delete_lead(client: AsyncClient, session: AsyncSession) -> None:
    owner = await create_user(session, email="emp6@ltarc.vn", password="x", role=Role.EMPLOYEE)
    lead = await create_lead(session, name="Lead sẽ xoá", owner_id=owner.id)

    resp = await client.delete(f"/api/leads/{lead.id}", headers=_auth_headers(owner))
    assert resp.status_code == 204

    resp = await client.get("/api/leads", headers=_auth_headers(owner))
    assert resp.json() == []


async def test_department_head_sees_only_own_department_leads(client: AsyncClient, session: AsyncSession) -> None:
    from app.services.department_service import create_department

    dept_a = await create_department(session, name="Thiết kế", head_user_id=None)
    dept_b = await create_department(session, name="Thi công", head_user_id=None)

    head_a = await create_user(session, email="heada@ltarc.vn", password="x", role=Role.DEPARTMENT_HEAD, department_id=dept_a.id)
    owner_b = await create_user(session, email="ownerb@ltarc.vn", password="x", role=Role.EMPLOYEE, department_id=dept_b.id)

    await create_lead(session, name="Lead của phòng A", owner_id=head_a.id)
    await create_lead(session, name="Lead của phòng B", owner_id=owner_b.id)

    resp = await client.get("/api/leads", headers=_auth_headers(head_a))
    assert resp.status_code == 200
    names = [item["name"] for item in resp.json()]
    assert names == ["Lead của phòng A"]
