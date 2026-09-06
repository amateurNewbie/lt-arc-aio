from datetime import date
from uuid import UUID

from sqlmodel import Field, SQLModel

from app.models.enums import ProjectCategory, ProjectStatus


class ProjectCreate(SQLModel):
    name: str
    client: str
    category: ProjectCategory
    manager_id: UUID
    """Quản lý dự án — chọn rõ trên form (4D)."""
    construction_head_id: UUID | None = None
    design_head_id: UUID | None = None
    member_ids: list[UUID] = Field(default_factory=list)
    lead_id: UUID | None = None
    type: str | None = None
    area: float | None = None
    budget: int | None = None
    start_date: date | None = None
    due_date: date | None = None
    stage_progress: dict | None = None
    """Optional — mặc định 5 giai đoạn 0% + deadline null."""


class ProjectUpdate(SQLModel):
    name: str | None = None
    client: str | None = None
    category: ProjectCategory | None = None
    manager_id: UUID | None = None
    construction_head_id: UUID | None = None
    design_head_id: UUID | None = None
    member_ids: list[UUID] | None = None
    lead_id: UUID | None = None
    type: str | None = None
    area: float | None = None
    budget: int | None = None
    status: ProjectStatus | None = None
    start_date: date | None = None
    due_date: date | None = None
    stage_progress: dict | None = None


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
    construction_head_id: UUID | None
    design_head_id: UUID | None
    start_date: date | None
    due_date: date | None
    member_ids: list[UUID] = Field(default_factory=list)


class ProjectMemberRead(SQLModel):
    user_id: UUID


class ProjectMembersReplaceRequest(SQLModel):
    user_ids: list[UUID] = Field(default_factory=list)


class ProjectDepartmentHeadAssign(SQLModel):
    department_id: UUID
    user_id: UUID


class ProjectAssignHeadsRequest(SQLModel):
    assignments: list[ProjectDepartmentHeadAssign]


class ProjectProgressUpdate(SQLModel):
    progress: int
    stage_progress: dict | None = None
