from datetime import date
from uuid import UUID

from sqlmodel import SQLModel

from app.models.enums import ProjectCategory, ProjectStatus


class ProjectCreate(SQLModel):
    name: str
    client: str
    category: ProjectCategory
    manager_id: UUID
    type: str | None = None
    area: float | None = None
    budget: int | None = None
    start_date: date | None = None
    due_date: date | None = None


class ProjectRead(SQLModel):
    id: UUID
    code: str
    name: str
    client: str
    category: ProjectCategory
    type: str | None
    area: float | None
    budget: int | None
    progress: int
    stage_progress: dict | None
    status: ProjectStatus
    lead_id: UUID | None
    manager_id: UUID
    start_date: date | None
    due_date: date | None


class ProjectDepartmentHeadAssign(SQLModel):
    department_id: UUID
    user_id: UUID


class ProjectAssignHeadsRequest(SQLModel):
    assignments: list[ProjectDepartmentHeadAssign]


class ProjectProgressUpdate(SQLModel):
    progress: int
    stage_progress: dict | None = None
