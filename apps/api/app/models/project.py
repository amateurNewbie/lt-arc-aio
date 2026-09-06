from datetime import date, datetime
from uuid import UUID, uuid4

from sqlalchemy import JSON, BigInteger, Column, UniqueConstraint
from sqlmodel import Field, SQLModel

from app.core.clock import utcnow
from app.models.enums import ProjectCategory, ProjectStatus

# FR-3.4 — khóa mặc định (seed); runtime lấy từ projectstagetemplate + JSON trên DA.
PROJECT_STAGE_KEYS = (
    "design",
    "permit",
    "rough_construction",
    "interior_finish",
    "handover",
)

PROJECT_STAGE_LABELS = {
    "design": "Thiết kế",
    "permit": "Xin phép xây dựng",
    "rough_construction": "Thi công phần thô",
    "interior_finish": "Hoàn thiện nội thất",
    "handover": "Nghiệm thu & bàn giao",
}


def default_stage_progress(keys: list[str] | None = None) -> dict:
    """Mỗi giai đoạn: {progress: 0..100, deadline: ISO date | null, name?: str}."""
    use_keys = keys if keys is not None else list(PROJECT_STAGE_KEYS)
    return {key: {"progress": 0, "deadline": None, "name": PROJECT_STAGE_LABELS.get(key, key)} for key in use_keys}


def normalize_stage_progress(raw: dict | None, template_keys: list[str] | None = None) -> dict:
    """Chuẩn hoá JSON giai đoạn — giữ mọi key có trong raw hoặc template."""
    if not raw and template_keys:
        return default_stage_progress(template_keys)
    if not raw:
        return default_stage_progress()

    keys = list(raw.keys())
    if template_keys:
        for k in template_keys:
            if k not in keys:
                keys.append(k)

    result: dict = {}
    for key in keys:
        value = raw.get(key)
        label = PROJECT_STAGE_LABELS.get(key, key)
        if isinstance(value, dict):
            progress = int(value.get("progress") or 0)
            deadline = value.get("deadline")
            name = value.get("name") or label
            result[key] = {"progress": max(0, min(100, progress)), "deadline": deadline, "name": name}
        elif isinstance(value, (int, float)):
            result[key] = {"progress": max(0, min(100, int(value))), "deadline": None, "name": label}
        else:
            result[key] = {"progress": 0, "deadline": None, "name": label}
    return result


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
