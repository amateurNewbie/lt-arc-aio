from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.deps import get_current_user, get_session, require_roles
from app.core.permissions import Role
from app.models.user import User
from app.models.work_item import WorkItem
from app.schemas.work_item import WorkItemCreate, WorkItemProgressUpdate, WorkItemRead
from app.services.work_item_service import create_work_item, list_work_items, update_progress

router = APIRouter(prefix="/api/projects/{project_id}/work-items", tags=["work-items"])


@router.get("", response_model=list[WorkItemRead])
async def list_work_items_endpoint(
    project_id: UUID,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(get_current_user),
) -> list[WorkItem]:
    return await list_work_items(session, project_id)


@router.post("", response_model=WorkItemRead, status_code=status.HTTP_201_CREATED)
async def create_work_item_endpoint(
    project_id: UUID,
    payload: WorkItemCreate,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR, Role.DEPARTMENT_HEAD)),
) -> WorkItem:
    """FR-5.5 — cùng quy tắc phân quyền với khai báo công việc (FR-5.1)."""
    if project_id != payload.project_id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "project_id mismatch")
    if user.role == Role.DEPARTMENT_HEAD and payload.department_id != user.department_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Chỉ được khai báo trong bộ phận của mình")

    return await create_work_item(
        session,
        project_id=payload.project_id,
        department_id=payload.department_id,
        name=payload.name,
        unit=payload.unit,
        quantity=payload.quantity,
        unit_price=payload.unit_price,
        actor=user,
        create_linked_task=payload.create_task,
    )


@router.patch("/{work_item_id}", response_model=WorkItemRead)
async def update_work_item_progress_endpoint(
    project_id: UUID,
    work_item_id: UUID,
    payload: WorkItemProgressUpdate,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR, Role.DEPARTMENT_HEAD)),
) -> WorkItem:
    """FR-5.5 — cập nhật % hoàn thành hạng mục công việc."""
    work_item = await session.get(WorkItem, work_item_id)
    if work_item is None or work_item.project_id != project_id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Work item not found")
    if user.role == Role.DEPARTMENT_HEAD and work_item.department_id != user.department_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Chỉ được cập nhật hạng mục trong bộ phận của mình")
    return await update_progress(session, work_item, progress=payload.progress)
