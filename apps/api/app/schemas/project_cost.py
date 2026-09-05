from datetime import date as date_type
from uuid import UUID

from sqlmodel import SQLModel


class ProjectCostCreate(SQLModel):
    cost_category_id: UUID
    work_item_id: UUID | None = None
    amount: int
    date: date_type | None = None
    note: str | None = None
    confirm_duplicate: bool = False
    """FR-6.6 — true khi user đã xác nhận không trùng, bỏ qua cảnh báo."""


class ProjectCostRead(SQLModel):
    id: UUID
    project_id: UUID
    cost_category_id: UUID
    work_item_id: UUID | None
    amount: int
    date: date_type
    note: str | None
    recorded_by_id: UUID


class DuplicateCostWarningResponse(SQLModel):
    duplicate_warning: bool = True
    existing_cost_id: UUID
    existing_amount: int
    existing_date: date_type
