from datetime import date
from uuid import UUID

from sqlmodel import col, select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.clock import utcnow
from app.core.permissions import Role
from app.models.enums import ProjectCategory, ProjectStatus
from app.services.stage_template_service import active_template_keys, list_templates
from app.models.project import (
    Project,
    ProjectDepartmentHead,
    ProjectMember,
    default_stage_progress,
    normalize_stage_progress,
)
from app.models.user import User
from app.services.activity_service import log_activity


async def generate_project_code(session: AsyncSession, *, on: date | None = None) -> str:
    """Mã dự án dạng LT-YYMM-NN, duy nhất toàn hệ thống (FR-3.1)."""
    on = on or utcnow().date()
    prefix = f"LT-{on:%y%m}-"
    result = await session.exec(select(Project.code).where(Project.code.like(f"{prefix}%")))
    existing = result.all()
    next_seq = len(existing) + 1
    return f"{prefix}{next_seq:02d}"


async def _replace_members(session: AsyncSession, project_id: UUID, user_ids: list[UUID]) -> list[UUID]:
    existing = await session.exec(select(ProjectMember).where(ProjectMember.project_id == project_id))
    for row in existing.all():
        await session.delete(row)
    await session.flush()

    unique_ids = list(dict.fromkeys(user_ids))
    for user_id in unique_ids:
        session.add(ProjectMember(project_id=project_id, user_id=user_id))
    await session.flush()
    return unique_ids


async def get_member_ids(session: AsyncSession, project_id: UUID) -> list[UUID]:
    result = await session.exec(select(ProjectMember.user_id).where(ProjectMember.project_id == project_id))
    return list(result.all())


async def user_can_access_project(session: AsyncSession, user: User, project: Project) -> bool:
    """FR-3.5 — Admin/Giám đốc xem tất cả; TB chỉ DA được gán (manager/head/member)."""
    if user.role in (Role.ADMIN, Role.DIRECTOR):
        return True
    if user.role != Role.DEPARTMENT_HEAD:
        return True

    if project.manager_id == user.id:
        return True
    if project.construction_head_id == user.id or project.design_head_id == user.id:
        return True

    head = await session.exec(
        select(ProjectDepartmentHead).where(
            ProjectDepartmentHead.project_id == project.id,
            ProjectDepartmentHead.user_id == user.id,
        )
    )
    if head.first() is not None:
        return True

    member = await session.exec(
        select(ProjectMember).where(
            ProjectMember.project_id == project.id,
            ProjectMember.user_id == user.id,
        )
    )
    return member.first() is not None


async def create_project(
    session: AsyncSession,
    *,
    name: str,
    client: str,
    category: ProjectCategory,
    manager_id: UUID,
    actor: User,
    type_: str | None = None,
    area: float | None = None,
    budget: int | None = None,
    lead_id: UUID | None = None,
    construction_head_id: UUID | None = None,
    design_head_id: UUID | None = None,
    member_ids: list[UUID] | None = None,
    start_date: date | None = None,
    due_date: date | None = None,
    stage_progress: dict | None = None,
) -> Project:
    """FR-3.1 — chỉ ADMIN/DIRECTOR tạo dự án (kiểm tra ở router qua require_roles)."""
    code = await generate_project_code(session)
    if stage_progress is not None:
        resolved_stages = normalize_stage_progress(stage_progress)
    else:
        templates = await list_templates(session, active_only=True)
        if templates:
            resolved_stages = {
                t.key: {"progress": 0, "deadline": None, "name": t.name} for t in templates
            }
        else:
            resolved_stages = default_stage_progress()
    project = Project(
        code=code,
        name=name,
        client=client,
        category=category,
        type=type_,
        area=area,
        budget=budget,
        manager_id=manager_id,
        construction_head_id=construction_head_id,
        design_head_id=design_head_id,
        lead_id=lead_id,
        start_date=start_date,
        due_date=due_date,
        stage_progress=resolved_stages,
        progress=0,
    )
    session.add(project)
    await session.flush()

    if member_ids:
        await _replace_members(session, project.id, member_ids)

    await session.commit()
    await session.refresh(project)

    await log_activity(
        session,
        icon="building",
        title=f"Tạo dự án mới: {project.name}",
        user_id=actor.id,
        project_id=project.id,
    )
    return project


async def update_project(
    session: AsyncSession,
    project: Project,
    *,
    fields: dict,
) -> Project:
    """Cập nhật theo dict đã `exclude_unset` — cho phép gán null để xoá head/lead."""
    if "name" in fields:
        project.name = fields["name"]
    if "client" in fields:
        project.client = fields["client"]
    if "category" in fields:
        project.category = fields["category"]
    if "manager_id" in fields and fields["manager_id"] is not None:
        project.manager_id = fields["manager_id"]
    if "construction_head_id" in fields:
        project.construction_head_id = fields["construction_head_id"]
    if "design_head_id" in fields:
        project.design_head_id = fields["design_head_id"]
    if "lead_id" in fields:
        project.lead_id = fields["lead_id"]
    if "type" in fields:
        project.type = fields["type"]
    if "area" in fields:
        project.area = fields["area"]
    if "budget" in fields:
        project.budget = fields["budget"]
    if "status" in fields:
        project.status = fields["status"]
    if "start_date" in fields:
        project.start_date = fields["start_date"]
    if "due_date" in fields:
        project.due_date = fields["due_date"]
    if "stage_progress" in fields and fields["stage_progress"] is not None:
        project.stage_progress = normalize_stage_progress(fields["stage_progress"])
        stages = project.stage_progress or {}
        values = [int((stages.get(k) or {}).get("progress") or 0) for k in stages]
        if values:
            project.progress = round(sum(values) / len(values))

    if "member_ids" in fields and fields["member_ids"] is not None:
        await _replace_members(session, project.id, list(fields["member_ids"]))

    session.add(project)
    await session.commit()
    await session.refresh(project)
    return project


async def list_projects(
    session: AsyncSession,
    actor: User,
    *,
    status: ProjectStatus | None = None,
    category: ProjectCategory | None = None,
    search: str | None = None,
) -> list[Project]:
    query = select(Project)

    if actor.role == Role.DEPARTMENT_HEAD:
        head_ids = select(ProjectDepartmentHead.project_id).where(ProjectDepartmentHead.user_id == actor.id)
        member_ids = select(ProjectMember.project_id).where(ProjectMember.user_id == actor.id)
        query = query.where(
            (Project.id.in_(head_ids))
            | (Project.id.in_(member_ids))
            | (Project.manager_id == actor.id)
            | (Project.construction_head_id == actor.id)
            | (Project.design_head_id == actor.id)
        )

    if status is not None:
        query = query.where(Project.status == status)
    if category is not None:
        query = query.where(Project.category == category)
    if search:
        like = f"%{search}%"
        query = query.where((Project.name.ilike(like)) | (Project.code.ilike(like)) | (Project.client.ilike(like)))

    result = await session.exec(query.order_by(col(Project.created_at).desc()))
    return list(result.all())


async def assign_department_heads(
    session: AsyncSession,
    project_id: UUID,
    assignments: list[tuple[UUID, UUID]],
) -> list[ProjectDepartmentHead]:
    """FR-3.5 — một dự án Trọn gói có thể có cả Trưởng bộ phận Thiết kế và Thi công."""
    created = []
    for department_id, user_id in assignments:
        link = ProjectDepartmentHead(project_id=project_id, department_id=department_id, user_id=user_id)
        session.add(link)
        created.append(link)
    await session.commit()
    for link in created:
        await session.refresh(link)
    return created


async def replace_project_members(
    session: AsyncSession,
    project_id: UUID,
    user_ids: list[UUID],
) -> list[UUID]:
    ids = await _replace_members(session, project_id, user_ids)
    await session.commit()
    return ids


async def update_progress(
    session: AsyncSession,
    project: Project,
    *,
    progress: int,
    stage_progress: dict | None,
) -> Project:
    """FR-3.4 — Giám đốc/Trưởng bộ phận điều chỉnh tay tiến độ tổng thể + theo giai đoạn."""
    project.progress = progress
    if stage_progress is not None:
        project.stage_progress = normalize_stage_progress(stage_progress)
    session.add(project)
    await session.commit()
    await session.refresh(project)
    return project
