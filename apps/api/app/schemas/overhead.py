from datetime import date as date_type
from uuid import UUID

from sqlmodel import SQLModel

from app.models.enums import AllocationBasis


class OverheadCostCreate(SQLModel):
    cost_category_id: UUID
    amount: int
    date: date_type
    note: str | None = None
    month: str
    """"YYYY-MM"."""


class OverheadCostRead(SQLModel):
    id: UUID
    cost_category_id: UUID
    amount: int
    date: date_type
    note: str | None
    month: str


class OverheadAllocationPreviewItem(SQLModel):
    project_id: UUID
    project_code: str
    revenue_share: float
    allocated_amount: int


class OverheadAllocationRequest(SQLModel):
    month: str
    basis: AllocationBasis = AllocationBasis.REVENUE


class OverheadAllocationRead(SQLModel):
    id: UUID
    month: str
    project_id: UUID
    revenue_share: float
    allocated_amount: int
