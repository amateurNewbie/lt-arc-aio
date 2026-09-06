from datetime import date
from uuid import UUID

from sqlmodel import SQLModel

from app.models.enums import TaskPriority, TaskStatus


class TaskCreate(SQLModel):
    title: str
    project_id: UUID
    department_id: UUID
    work_item_id: UUID | None = None
    description: str | None = None
    parent_task_id: UUID | None = None
    due_date: date | None = None
    priority: TaskPriority = TaskPriority.MEDIUM
    assignee_id: UUID | None = None


class TaskRead(SQLModel):
    id: UUID
    title: str
    description: str | None
    project_id: UUID
    department_id: UUID
    work_item_id: UUID | None
    parent_task_id: UUID | None
    due_date: date | None
    priority: TaskPriority
    status: TaskStatus
    progress: int
    assignee_id: UUID | None
    is_overdue: bool = False


class TaskProgressUpdate(SQLModel):
    progress: int
