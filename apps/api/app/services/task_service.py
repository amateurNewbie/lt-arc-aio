from datetime import date
from uuid import UUID

from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.clock import utcnow
from app.core.permissions import Role
from app.models.enums import TaskPriority, TaskStatus, WorkItemStatus
from app.models.project import Project, ProjectDepartmentHead, ProjectMember
from app.models.task import Task
from app.models.user import User
from app.models.work_item import WorkItem
from app.services.activity_service import log_activity


class IncompleteSubtasksError(Exception):
    """FR-5.2 — công việc cha không tự chuyển 'Đã hoàn thành' khi còn đầu việc con chưa xong."""


class MissingWorkItemError(Exception):
    """Công việc phải gắn hạng mục công việc (trừ khi kế thừa từ cha)."""


async def create_task(
    session: AsyncSession,
    *,
    title: str,
    project_id: UUID,
    department_id: UUID,
    actor: User,
    work_item_id: UUID | None = None,
    description: str | None = None,
    parent_task_id: UUID | None = None,
    due_date: date | None = None,
    priority: TaskPriority = TaskPriority.MEDIUM,
    assignee_id: UUID | None = None,
) -> Task:
    """FR-5.1/5.2 — tạo công việc hoặc đầu việc con (khi có parent_task_id)."""
    resolved_work_item_id = work_item_id
    if parent_task_id is not None:
        parent = await session.get(Task, parent_task_id)
        if parent is not None and resolved_work_item_id is None:
            resolved_work_item_id = parent.work_item_id

    if resolved_work_item_id is None:
        raise MissingWorkItemError()

    work_item = await session.get(WorkItem, resolved_work_item_id)
    if work_item is None or work_item.project_id != project_id:
        raise MissingWorkItemError()

    task = Task(
        title=title,
        description=description,
        project_id=project_id,
        department_id=department_id,
        work_item_id=resolved_work_item_id,
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


async def _sync_work_item_progress(session: AsyncSession, work_item_id: UUID) -> None:
    """Trung bình tiến độ các công việc gắn hạng mục → cập nhật % hạng mục."""
    result = await session.exec(select(Task).where(Task.work_item_id == work_item_id))
    linked = list(result.all())
    work_item = await session.get(WorkItem, work_item_id)
    if work_item is None:
        return

    progress = round(sum(t.progress for t in linked) / len(linked)) if linked else 0
    progress = max(0, min(100, progress))
    work_item.progress = progress
    if progress == 100:
        work_item.status = WorkItemStatus.DONE
    elif progress > 0:
        work_item.status = WorkItemStatus.IN_PROGRESS
    else:
        work_item.status = WorkItemStatus.NOT_STARTED
    session.add(work_item)


async def update_progress(session: AsyncSession, task: Task, *, progress: int, actor: User) -> Task:
    """Cập nhật tiến độ: 0→Cần làm, >0→Đang làm, 100→Hoàn thành (trừ khi còn con dở)."""
    progress = max(0, min(100, progress))
    task.progress = progress

    if progress == 100:
        if await _has_incomplete_subtasks(session, task.id):
            raise IncompleteSubtasksError()
        task.status = TaskStatus.DONE
    elif progress > 0:
        task.status = TaskStatus.DOING
    else:
        task.status = TaskStatus.TODO

    if task.work_item_id is not None:
        await _sync_work_item_progress(session, task.work_item_id)

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
    """Admin/Giám đốc: tất cả; TB: việc thuộc DA được gán; Nhân viên: việc assign cho mình."""
    query = select(Task)

    if actor.role == Role.EMPLOYEE:
        query = query.where(Task.assignee_id == actor.id)
    elif actor.role == Role.DEPARTMENT_HEAD:
        head_ids = select(ProjectDepartmentHead.project_id).where(ProjectDepartmentHead.user_id == actor.id)
        member_ids = select(ProjectMember.project_id).where(ProjectMember.user_id == actor.id)
        accessible = select(Project.id).where(
            (Project.id.in_(head_ids))
            | (Project.id.in_(member_ids))
            | (Project.manager_id == actor.id)
            | (Project.construction_head_id == actor.id)
            | (Project.design_head_id == actor.id)
        )
        query = query.where(Task.project_id.in_(accessible))

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
