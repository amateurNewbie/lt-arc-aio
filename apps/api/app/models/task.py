from datetime import date, datetime
from uuid import UUID, uuid4

from sqlmodel import Field, SQLModel

from app.core.clock import utcnow
from app.models.enums import TaskPriority, TaskStatus


class Task(SQLModel, table=True):
    """FR-5 — công việc / đầu việc con thuộc một dự án."""

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    title: str
    description: str | None = Field(default=None)

    project_id: UUID = Field(foreign_key="project.id", index=True)
    department_id: UUID = Field(foreign_key="department.id", index=True)
    work_item_id: UUID | None = Field(default=None, foreign_key="workitem.id", index=True)
    parent_task_id: UUID | None = Field(default=None, foreign_key="task.id", index=True)

    due_date: date | None = Field(default=None)
    priority: TaskPriority = Field(default=TaskPriority.MEDIUM)
    status: TaskStatus = Field(default=TaskStatus.TODO, index=True)
    progress: int = Field(default=0)
    assignee_id: UUID | None = Field(default=None, foreign_key="user.id", index=True)

    created_at: datetime = Field(default_factory=utcnow)
