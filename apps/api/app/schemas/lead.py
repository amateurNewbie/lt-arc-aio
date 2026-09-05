from datetime import datetime
from uuid import UUID

from sqlmodel import SQLModel

from app.models.enums import LeadStatus, ProjectCategory


class LeadCreate(SQLModel):
    name: str
    phone: str | None = None
    email: str | None = None
    need: str | None = None
    budget_estimate: int | None = None
    source: str | None = None
    note: str | None = None
    owner_id: UUID | None = None
    """Nếu bỏ trống, mặc định là người tạo (FR-2.1)."""


class LeadUpdate(SQLModel):
    name: str | None = None
    phone: str | None = None
    email: str | None = None
    need: str | None = None
    budget_estimate: int | None = None
    source: str | None = None
    owner_id: UUID | None = None
    status: LeadStatus | None = None
    note: str | None = None
    """Ghi chú kèm theo lần chuyển trạng thái (FR-2.2) — chỉ áp dụng khi `status` được gửi kèm."""


class LeadRead(SQLModel):
    id: UUID
    name: str
    phone: str | None
    email: str | None
    need: str | None
    budget_estimate: int | None
    source: str | None
    note: str | None
    owner_id: UUID
    status: LeadStatus
    converted_project_id: UUID | None
    created_at: datetime


class LeadConvertRequest(SQLModel):
    category: ProjectCategory
    manager_id: UUID
    type: str | None = None
    area: float | None = None
    budget: int | None = None
