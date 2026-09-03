from httpx import AsyncClient
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.permissions import Role
from app.core.security import create_access_token
from app.models.enums import LeadStatus, ProjectCategory
from app.services.auth_service import create_user
from app.services.lead_service import LeadAlreadyConvertedError, convert_to_project, create_lead


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


async def test_employee_cannot_access_leads(client: AsyncClient, session: AsyncSession) -> None:
    """RBAC §2.6 — Nhân viên không có quyền xem khách hàng tiềm năng."""
    employee = await create_user(session, email="emp1@ltarc.vn", password="x", role=Role.EMPLOYEE)

    resp = await client.get("/api/leads", headers=_auth_headers(employee))
    assert resp.status_code == 403


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
