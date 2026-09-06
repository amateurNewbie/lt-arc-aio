"""FR-3 Phase A — tạo dự án kèm heads/members/stage_progress."""

from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.permissions import Role
from app.models.enums import ProjectCategory
from app.models.project import normalize_stage_progress
from app.services.auth_service import create_user
from app.services.project_service import create_project, get_member_ids


async def test_create_project_with_heads_members_and_stages(session: AsyncSession) -> None:
    director = await create_user(session, email="proj-a-dir@ltarc.vn", password="x", role=Role.DIRECTOR)
    construction = await create_user(session, email="proj-a-cons@ltarc.vn", password="x", role=Role.DEPARTMENT_HEAD)
    design = await create_user(session, email="proj-a-des@ltarc.vn", password="x", role=Role.DEPARTMENT_HEAD)
    staff = await create_user(session, email="proj-a-staff@ltarc.vn", password="x", role=Role.EMPLOYEE)

    project = await create_project(
        session,
        name="Biệt thự Phase A",
        client="Anh Tuấn",
        category=ProjectCategory.TURNKEY,
        manager_id=director.id,
        actor=director,
        construction_head_id=construction.id,
        design_head_id=design.id,
        member_ids=[staff.id, construction.id],
        budget=680_000_000,
        stage_progress={
            "design": {"progress": 0, "deadline": "2026-10-01"},
            "permit": 0,
        },
    )

    assert project.construction_head_id == construction.id
    assert project.design_head_id == design.id
    assert project.manager_id == director.id
    assert project.stage_progress is not None
    assert project.stage_progress["design"]["progress"] == 0
    assert project.stage_progress["design"]["deadline"] == "2026-10-01"
    assert project.stage_progress["permit"]["progress"] == 0
    assert project.stage_progress["handover"]["progress"] == 0

    members = await get_member_ids(session, project.id)
    assert set(members) == {staff.id, construction.id}


def test_normalize_stage_progress_legacy_ints() -> None:
    normalized = normalize_stage_progress({"design": 100, "permit": 50})
    assert normalized["design"] == {"progress": 100, "deadline": None}
    assert normalized["permit"]["progress"] == 50
    assert normalized["handover"]["progress"] == 0
