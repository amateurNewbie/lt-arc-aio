from datetime import date
from uuid import UUID

from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.clock import utcnow
from app.core.permissions import Role
from app.models.enums import TaskPriority, TaskStatus
from app.models.task import Task
from app.models.user import User
from app.services.activity_service import log_activity


class IncompleteSubtasksError(Exception):
    """FR-5.2 — công việc cha không tự chuyển 'Đã hoàn thành' khi còn đầu việc con chưa xong."""


async def create_task(
    session: AsyncSession,
    *,
    title: str,
    project_id: UUID,
    department_id: UUID,
    actor: User,
    description: str | None = None,
    parent_task_id: UUID | None = None,
    due_date: date | None = None,
    priority: TaskPriority = TaskPriority.MEDIUM,
    assignee_id: UUID | None = None,
) -> Task:
    """FR-5.1/5.2 — tạo công việc hoặc đầu việc con (khi có parent_task_id)."""
    task = Task(
        title=title,
        description=description,
        project_id=project_id,
        department_id=department_id,
        parent_task_id=parent_task_id,
        due_date=due_date,
        priority=priority,
        assignee_id=assignee_id,
    )
    session.add(task)
    await session.commit()
    await session.refresh(task)
    await log_activity(session, icon="list-plus", title=f'Tạo công việc "{title}"', user_id=actor.id, project_id=project_id)
    return task


async def _has_incomplete_subtasks(session: AsyncSession, task_id: UUID) -> bool:
    result = await session.exec(
        select(Task).where(Task.parent_task_id == task_id, Task.status != TaskStatus.DONE)
    )
    return result.first() is not None


async def update_progress(session: AsyncSession, task: Task, *, progress: int, actor: User) -> Task:
    """FR-5.3 — tiến độ đạt 100% tự động chuyển 'Đã hoàn thành', trừ khi còn
    đầu việc con dở dang (FR-5.2)."""
    progress = max(0, min(100, progress))
    task.progress = progress

    if progress == 100:
        if await _has_incomplete_subtasks(session, task.id):
            raise IncompleteSubtasksError()
        task.status = TaskStatus.DONE
    elif task.status == TaskStatus.DONE:
        task.status = TaskStatus.DOING

    session.add(task)
    await session.commit()
    await session.refresh(task)
    await log_activity(
        session,
        icon="activity",
        title=f'Cập nhật tiến độ "{task.title}" ({progress}%)',
        user_id=actor.id,
        project_id=task.project_id,
    )
    return task


async def list_tasks(
    session: AsyncSession,
    actor: User,
    *,
    project_id: UUID | None = None,
    department_id: UUID | None = None,
    assignee_id: UUID | None = None,
    status: TaskStatus | None = None,
) -> list[Task]:
    """FR-5.4 — danh sách/Kanban; RBAC §2.6 — Nhân viên chỉ thấy việc của mình,
    Trưởng bộ phận chỉ thấy việc trong bộ phận."""
    query = select(Task)

    if actor.role == Role.EMPLOYEE:
        query = query.where(Task.assignee_id == actor.id)
    elif actor.role == Role.DEPARTMENT_HEAD:
        query = query.where(Task.department_id == actor.department_id)

    if project_id is not None:
        query = query.where(Task.project_id == project_id)
    if department_id is not None:
        query = query.where(Task.department_id == department_id)
    if assignee_id is not None:
        query = query.where(Task.assignee_id == assignee_id)
    if status is not None:
        query = query.where(Task.status == status)

    result = await session.exec(query.order_by(Task.due_date))
    return list(result.all())


def is_overdue(task: Task) -> bool:
    """FR-5.6 — quá hạn hoàn thành nhưng chưa 'Đã hoàn thành'."""
    return task.due_date is not None and task.due_date < utcnow().date() and task.status != TaskStatus.DONE
