from datetime import date
from uuid import UUID

from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.clock import utcnow
from app.core.permissions import Role
from app.models.enums import ProjectCategory, ProjectStatus
from app.models.project import Project, ProjectDepartmentHead
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
    start_date: date | None = None,
    due_date: date | None = None,
) -> Project:
    """FR-3.1 — chỉ ADMIN/DIRECTOR tạo dự án (kiểm tra ở router qua require_roles)."""
    code = await generate_project_code(session)
    project = Project(
        code=code,
        name=name,
        client=client,
        category=category,
        type=type_,
        area=area,
        budget=budget,
        manager_id=manager_id,
        lead_id=lead_id,
        start_date=start_date,
        due_date=due_date,
    )
    session.add(project)
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
        own_project_ids = select(ProjectDepartmentHead.project_id).where(ProjectDepartmentHead.user_id == actor.id)
        query = query.where(Project.id.in_(own_project_ids))

    if status is not None:
        query = query.where(Project.status == status)
    if category is not None:
        query = query.where(Project.category == category)
    if search:
        like = f"%{search}%"
        query = query.where((Project.name.ilike(like)) | (Project.code.ilike(like)) | (Project.client.ilike(like)))

    result = await session.exec(query.order_by(Project.created_at.desc()))
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
        project.stage_progress = stage_progress
    session.add(project)
    await session.commit()
    await session.refresh(project)
    return project
