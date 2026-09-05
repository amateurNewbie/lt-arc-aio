from uuid import UUID

from sqlmodel import SQLModel


class DepartmentCreate(SQLModel):
    name: str
    head_user_id: UUID | None = None


class DepartmentUpdate(SQLModel):
    name: str | None = None
    head_user_id: UUID | None = None


class DepartmentRead(SQLModel):
    id: UUID
    name: str
    head_user_id: UUID | None
    employee_count: int
    active_task_count: int
    avg_task_progress: float
