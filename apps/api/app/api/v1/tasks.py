from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.deps import get_current_user, get_session, require_roles
from app.core.permissions import Role
from app.models.enums import TaskStatus
from app.models.task import Task
from app.models.user import User
from app.schemas.task import TaskCreate, TaskProgressUpdate, TaskRead
from app.services.task_service import IncompleteSubtasksError, create_task, is_overdue, list_tasks, update_progress

router = APIRouter(prefix="/api/tasks", tags=["tasks"])


def _to_read(task: Task) -> TaskRead:
    return TaskRead(
        id=task.id,
        title=task.title,
        description=task.description,
        project_id=task.project_id,
        department_id=task.department_id,
        parent_task_id=task.parent_task_id,
        due_date=task.due_date,
        priority=task.priority,
        status=task.status,
        progress=task.progress,
        assignee_id=task.assignee_id,
        is_overdue=is_overdue(task),
    )


@router.get("", response_model=list[TaskRead])
async def list_tasks_endpoint(
    project_id: UUID | None = None,
    department_id: UUID | None = None,
    assignee_id: UUID | None = None,
    status_filter: TaskStatus | None = None,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
) -> list[TaskRead]:
    """FR-5.4 — danh sách/Kanban (nhóm theo status ở client)."""
    tasks = await list_tasks(
        session,
        user,
        project_id=project_id,
        department_id=department_id,
        assignee_id=assignee_id,
        status=status_filter,
    )
    return [_to_read(t) for t in tasks]


@router.post("", response_model=TaskRead, status_code=status.HTTP_201_CREATED)
async def create_task_endpoint(
    payload: TaskCreate,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR, Role.DEPARTMENT_HEAD)),
) -> TaskRead:
    """FR-5.1/5.2 — Trưởng bộ phận chỉ giao việc trong bộ phận mình."""
    if user.role == Role.DEPARTMENT_HEAD and payload.department_id != user.department_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Chỉ được giao việc trong bộ phận của mình")

    task = await create_task(
        session,
        title=payload.title,
        project_id=payload.project_id,
        department_id=payload.department_id,
        actor=user,
        description=payload.description,
        parent_task_id=payload.parent_task_id,
        due_date=payload.due_date,
        priority=payload.priority,
        assignee_id=payload.assignee_id,
    )
    return _to_read(task)


@router.patch("/{task_id}", response_model=TaskRead)
async def update_task_progress_endpoint(
    task_id: UUID,
    payload: TaskProgressUpdate,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
) -> TaskRead:
    """FR-5.3; RBAC §2.6 — Nhân viên chỉ cập nhật việc của bản thân, Trưởng bộ
    phận chỉ việc trong bộ phận."""
    task = await session.get(Task, task_id)
    if task is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Task not found")

    if user.role == Role.EMPLOYEE and task.assignee_id != user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Chỉ được cập nhật công việc của chính mình")
    if user.role == Role.DEPARTMENT_HEAD and task.department_id != user.department_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Chỉ được cập nhật công việc trong bộ phận của mình")

    try:
        task = await update_progress(session, task, progress=payload.progress, actor=user)
    except IncompleteSubtasksError as exc:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "Còn đầu việc con chưa hoàn thành, không thể đánh dấu xong",
        ) from exc
    return _to_read(task)


@router.delete("/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_task_endpoint(
    task_id: UUID,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR, Role.DEPARTMENT_HEAD)),
) -> None:
    task = await session.get(Task, task_id)
    if task is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Task not found")
    await session.delete(task)
    await session.commit()
