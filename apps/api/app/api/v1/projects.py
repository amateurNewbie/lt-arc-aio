from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import select
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
    ProjectProgressUpdate,
    ProjectRead,
)
from app.schemas.reports import ProjectPnl
from app.services.pnl_service import project_pnl
from app.services.project_service import assign_department_heads, create_project, list_projects, update_progress

router = APIRouter(prefix="/api/projects", tags=["projects"])


@router.get("", response_model=list[ProjectRead])
async def list_projects_endpoint(
    status_filter: ProjectStatus | None = None,
    category: ProjectCategory | None = None,
    search: str | None = None,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
) -> list[Project]:
    """FR-3.2 — Trưởng bộ phận chỉ thấy dự án mình được phân công (FR-3.5)."""
    return await list_projects(session, user, status=status_filter, category=category, search=search)


@router.post("", response_model=ProjectRead, status_code=status.HTTP_201_CREATED)
async def create_project_endpoint(
    payload: ProjectCreate,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> Project:
    """FR-3.1 — chỉ Admin/Giám đốc tạo/sửa/xoá dự án."""
    return await create_project(
        session,
        name=payload.name,
        client=payload.client,
        category=payload.category,
        manager_id=payload.manager_id,
        actor=user,
        type_=payload.type,
        area=payload.area,
        budget=payload.budget,
        start_date=payload.start_date,
        due_date=payload.due_date,
    )


@router.get("/{project_id}", response_model=ProjectRead)
async def get_project_endpoint(
    project_id: UUID,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(get_current_user),
) -> Project:
    """FR-3.3 — trang chi tiết dự án."""
    project = await session.get(Project, project_id)
    if project is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Project not found")
    return project


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
) -> Project:
    """FR-3.4 — Giám đốc/Trưởng bộ phận điều chỉnh tay tiến độ."""
    project = await session.get(Project, project_id)
    if project is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Project not found")
    return await update_progress(session, project, progress=payload.progress, stage_progress=payload.stage_progress)


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

    if user.role == Role.DEPARTMENT_HEAD:
        result = await session.exec(
            select(ProjectDepartmentHead).where(
                ProjectDepartmentHead.project_id == project_id,
                ProjectDepartmentHead.user_id == user.id,
            )
        )
        if result.first() is None:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Không phải dự án bạn phụ trách")

    return await project_pnl(session, project_id)
