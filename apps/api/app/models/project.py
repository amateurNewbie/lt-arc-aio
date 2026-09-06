from datetime import date, datetime
from uuid import UUID, uuid4

from sqlalchemy import JSON, BigInteger, Column, UniqueConstraint
from sqlmodel import Field, SQLModel

from app.core.clock import utcnow
from app.models.enums import ProjectCategory, ProjectStatus

# FR-3.4 — khóa giai đoạn tiến độ (khớp LT-ARC-Web-UI + BRD).
PROJECT_STAGE_KEYS = (
    "design",
    "permit",
    "rough_construction",
    "interior_finish",
    "handover",
)


def default_stage_progress() -> dict:
    """Mỗi giai đoạn: {progress: 0..100, deadline: ISO date | null}."""
    return {key: {"progress": 0, "deadline": None} for key in PROJECT_STAGE_KEYS}


def normalize_stage_progress(raw: dict | None) -> dict:
    """Chuẩn hoá JSON cũ `{"design": 100}` → `{"design": {"progress": 100, "deadline": null}}`."""
    base = default_stage_progress()
    if not raw:
        return base
    for key in PROJECT_STAGE_KEYS:
        value = raw.get(key)
        if isinstance(value, dict):
            progress = int(value.get("progress") or 0)
            deadline = value.get("deadline")
            base[key] = {"progress": max(0, min(100, progress)), "deadline": deadline}
        elif isinstance(value, (int, float)):
            base[key] = {"progress": max(0, min(100, int(value))), "deadline": None}
    return base


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
    """FR-3.4 — % + deadline theo giai đoạn, vd {"design": {"progress": 100, "deadline": "2026-10-01"}, ...}."""

    status: ProjectStatus = Field(default=ProjectStatus.PLANNING, index=True)

    lead_id: UUID | None = Field(default=None, foreign_key="lead.id")
    manager_id: UUID = Field(foreign_key="user.id")
    """Quản lý dự án (PM) — chọn rõ trên form (chốt plan 4D)."""
    construction_head_id: UUID | None = Field(default=None, foreign_key="user.id")
    """Trưởng bộ phận Thi công — tối đa 1 người (chốt plan 2B)."""
    design_head_id: UUID | None = Field(default=None, foreign_key="user.id")
    """Trưởng bộ phận Thiết kế — tối đa 1 người (chốt plan 2B)."""

    start_date: date | None = Field(default=None)
    due_date: date | None = Field(default=None)
    created_at: datetime = Field(default_factory=utcnow)


class ProjectDepartmentHead(SQLModel, table=True):
    """FR-3.5 — phân công nhiều Trưởng bộ phận phụ trách trong cùng một dự án."""

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    project_id: UUID = Field(foreign_key="project.id", index=True)
    department_id: UUID = Field(foreign_key="department.id", index=True)
    user_id: UUID = Field(foreign_key="user.id", index=True)


class ProjectMember(SQLModel, table=True):
    """Nhân viên được gán vào dự án (nhiều người)."""

    __table_args__ = (UniqueConstraint("project_id", "user_id", name="uq_project_member_project_user"),)

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    project_id: UUID = Field(foreign_key="project.id", index=True)
    user_id: UUID = Field(foreign_key="user.id", index=True)
    created_at: datetime = Field(default_factory=utcnow)
