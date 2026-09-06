from uuid import UUID

from sqlmodel import SQLModel

from app.models.enums import WorkItemStatus


class WorkItemCreate(SQLModel):
    project_id: UUID
    department_id: UUID
    name: str
    unit: str = "-"
    quantity: float = 1
    unit_price: int = 0
    create_task: bool = True


class WorkItemProgressUpdate(SQLModel):
    progress: int


class WorkItemRead(SQLModel):
    id: UUID
    project_id: UUID
    department_id: UUID
    name: str
    unit: str
    quantity: float
    unit_price: int
    amount: int
    progress: int
    status: WorkItemStatus
