"""FR-3 Phase E — TB chỉ thấy / mở dự án được gán."""

from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.permissions import Role
from app.models.enums import ProjectCategory
from app.services.auth_service import create_user
from app.services.project_service import create_project, list_projects, user_can_access_project


async def test_department_head_only_sees_assigned_projects(session: AsyncSession) -> None:
    director = await create_user(session, email="proj-e-dir@ltarc.vn", password="x", role=Role.DIRECTOR)
    head = await create_user(session, email="proj-e-head@ltarc.vn", password="x", role=Role.DEPARTMENT_HEAD)
    other = await create_user(session, email="proj-e-other@ltarc.vn", password="x", role=Role.DEPARTMENT_HEAD)

    assigned = await create_project(
        session,
        name="DA được gán",
        client="KH A",
        category=ProjectCategory.CONSTRUCTION,
        manager_id=director.id,
        actor=director,
        design_head_id=head.id,
    )
    await create_project(
        session,
        name="DA không gán",
        client="KH B",
        category=ProjectCategory.CONSTRUCTION,
        manager_id=director.id,
        actor=director,
        construction_head_id=other.id,
    )

    visible = await list_projects(session, head)
    assert {p.id for p in visible} == {assigned.id}
    assert await user_can_access_project(session, head, assigned) is True

    hidden = next(p for p in await list_projects(session, director) if p.id != assigned.id)
    assert await user_can_access_project(session, head, hidden) is False


async def test_department_head_sees_member_projects(session: AsyncSession) -> None:
    director = await create_user(session, email="proj-e2-dir@ltarc.vn", password="x", role=Role.DIRECTOR)
    head = await create_user(session, email="proj-e2-head@ltarc.vn", password="x", role=Role.DEPARTMENT_HEAD)

    project = await create_project(
        session,
        name="DA member",
        client="KH C",
        category=ProjectCategory.DESIGN,
        manager_id=director.id,
        actor=director,
        member_ids=[head.id],
    )

    visible = await list_projects(session, head)
    assert project.id in {p.id for p in visible}
    assert await user_can_access_project(session, head, project) is True
