from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.deps import get_current_user, get_session, require_roles
from app.core.permissions import Role
from app.models.enums import ProjectCategory, ProjectStatus
from app.models.project import Project, ProjectDepartmentHead
from app.models.user import User
from app.schemas.project import (
    ProjectAssignHeadsRequest,
    ProjectCreate,
    ProjectDepartmentHeadAssign,
    ProjectMemberRead,
    ProjectMembersReplaceRequest,
    ProjectProgressUpdate,
    ProjectRead,
    ProjectUpdate,
)
from app.schemas.reports import ProjectPnl
from app.services.pnl_service import project_pnl
from app.services.project_service import (
    assign_department_heads,
    create_project,
    get_member_ids,
    list_projects,
    replace_project_members,
    update_progress,
    update_project,
    user_can_access_project,
)

router = APIRouter(prefix="/api/projects", tags=["projects"])


async def _to_read(session: AsyncSession, project: Project) -> ProjectRead:
    member_ids = await get_member_ids(session, project.id)
    data = project.model_dump()
    data["member_ids"] = member_ids
    return ProjectRead(**data)


@router.get("", response_model=list[ProjectRead])
async def list_projects_endpoint(
    status_filter: ProjectStatus | None = None,
    category: ProjectCategory | None = None,
    search: str | None = None,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
) -> list[ProjectRead]:
    """FR-3.2 — Trưởng bộ phận chỉ thấy dự án mình được phân công (FR-3.5)."""
    projects = await list_projects(session, user, status=status_filter, category=category, search=search)
    return [await _to_read(session, p) for p in projects]


@router.post("", response_model=ProjectRead, status_code=status.HTTP_201_CREATED)
async def create_project_endpoint(
    payload: ProjectCreate,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> ProjectRead:
    """FR-3.1 — chỉ Admin/Giám đốc tạo dự án."""
    project = await create_project(
        session,
        name=payload.name,
        client=payload.client,
        category=payload.category,
        manager_id=payload.manager_id,
        actor=user,
        type_=payload.type,
        area=payload.area,
        budget=payload.budget,
        lead_id=payload.lead_id,
        construction_head_id=payload.construction_head_id,
        design_head_id=payload.design_head_id,
        member_ids=payload.member_ids,
        start_date=payload.start_date,
        due_date=payload.due_date,
        stage_progress=payload.stage_progress,
    )
    return await _to_read(session, project)


@router.get("/{project_id}", response_model=ProjectRead)
async def get_project_endpoint(
    project_id: UUID,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
) -> ProjectRead:
    """FR-3.3 — trang chi tiết dự án; TB chỉ mở DA được gán."""
    project = await session.get(Project, project_id)
    if project is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Project not found")
    if not await user_can_access_project(session, user, project):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Không phải dự án bạn phụ trách")
    return await _to_read(session, project)


@router.patch("/{project_id}", response_model=ProjectRead)
async def update_project_endpoint(
    project_id: UUID,
    payload: ProjectUpdate,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> ProjectRead:
    """Cập nhật hồ sơ dự án (heads, members, stage_progress, ...)."""
    project = await session.get(Project, project_id)
    if project is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Project not found")
    updated = await update_project(
        session,
        project,
        fields=payload.model_dump(exclude_unset=True),
    )
    return await _to_read(session, updated)


@router.get("/{project_id}/members", response_model=list[ProjectMemberRead])
async def list_members_endpoint(
    project_id: UUID,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(get_current_user),
) -> list[ProjectMemberRead]:
    project = await session.get(Project, project_id)
    if project is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Project not found")
    ids = await get_member_ids(session, project_id)
    return [ProjectMemberRead(user_id=uid) for uid in ids]


@router.put("/{project_id}/members", response_model=list[ProjectMemberRead])
async def replace_members_endpoint(
    project_id: UUID,
    payload: ProjectMembersReplaceRequest,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> list[ProjectMemberRead]:
    project = await session.get(Project, project_id)
    if project is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Project not found")
    ids = await replace_project_members(session, project_id, payload.user_ids)
    return [ProjectMemberRead(user_id=uid) for uid in ids]


@router.post(
    "/{project_id}/department-heads",
    response_model=list[ProjectDepartmentHeadAssign],
    status_code=status.HTTP_201_CREATED,
)
async def assign_department_heads_endpoint(
    project_id: UUID,
    payload: ProjectAssignHeadsRequest,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> list[ProjectDepartmentHeadAssign]:
    """FR-3.5 — phân công nhiều Trưởng bộ phận cho cùng một dự án."""
    project = await session.get(Project, project_id)
    if project is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Project not found")

    links = await assign_department_heads(
        session,
        project_id,
        [(a.department_id, a.user_id) for a in payload.assignments],
    )
    return [ProjectDepartmentHeadAssign(department_id=link.department_id, user_id=link.user_id) for link in links]


@router.patch("/{project_id}/progress", response_model=ProjectRead)
async def update_progress_endpoint(
    project_id: UUID,
    payload: ProjectProgressUpdate,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR, Role.DEPARTMENT_HEAD)),
) -> ProjectRead:
    """FR-3.4 — Giám đốc/Trưởng bộ phận điều chỉnh tay tiến độ."""
    project = await session.get(Project, project_id)
    if project is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Project not found")
    updated = await update_progress(session, project, progress=payload.progress, stage_progress=payload.stage_progress)
    return await _to_read(session, updated)


@router.get("/{project_id}/financial-summary", response_model=ProjectPnl)
async def project_financial_summary_endpoint(
    project_id: UUID,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR, Role.DEPARTMENT_HEAD)),
) -> dict:
    """FR-11.2/11.6 — Lãi/Lỗ của một dự án; Trưởng bộ phận chỉ xem dự án mình phụ trách."""
    project = await session.get(Project, project_id)
    if project is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Project not found")
    if not await user_can_access_project(session, user, project):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Không phải dự án bạn phụ trách")
    return await project_pnl(session, project_id)
