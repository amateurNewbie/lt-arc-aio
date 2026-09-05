from datetime import date, datetime
from uuid import UUID, uuid4

from sqlalchemy import JSON, BigInteger, Column
from sqlmodel import Field, SQLModel

from app.core.clock import utcnow
from app.models.enums import ProjectCategory, ProjectStatus


class Project(SQLModel, table=True):
    """FR-3 — hồ sơ dự án thiết kế/thi công."""

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    code: str = Field(unique=True, index=True)
    name: str
    client: str
    category: ProjectCategory = Field(index=True)
    type: str | None = Field(default=None)  # loại hình công trình (Nhà phố, Biệt thự, ...)
    area: float | None = Field(default=None)  # m2

    budget: int | None = Field(default=None, sa_type=BigInteger)  # BIGINT VND — ngân sách hợp đồng
    progress: int = Field(default=0)  # % tổng thể (FR-3.4)
    stage_progress: dict | None = Field(default=None, sa_column=Column(JSON))
    """FR-3.4 — % theo giai đoạn, vd {"design": 100, "permit": 100, "rough_construction": 85, ...}."""

    status: ProjectStatus = Field(default=ProjectStatus.PLANNING, index=True)

    lead_id: UUID | None = Field(default=None, foreign_key="lead.id")
    manager_id: UUID = Field(foreign_key="user.id")

    start_date: date | None = Field(default=None)
    due_date: date | None = Field(default=None)
    created_at: datetime = Field(default_factory=utcnow)


class ProjectDepartmentHead(SQLModel, table=True):
    """FR-3.5 — phân công nhiều Trưởng bộ phận phụ trách trong cùng một dự án."""

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    project_id: UUID = Field(foreign_key="project.id", index=True)
    department_id: UUID = Field(foreign_key="department.id", index=True)
    user_id: UUID = Field(foreign_key="user.id", index=True)
