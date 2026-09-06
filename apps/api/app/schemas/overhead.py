from datetime import date
from uuid import UUID

from sqlmodel import SQLModel

from app.models.enums import CostCategoryScope  # noqa: F401 — kept for schema imports consistency


class OverheadCostCreate(SQLModel):
    cost_category_id: UUID
    amount: int
    date: date
    fund_account_id: UUID
    note: str | None = None
    month: str


class OverheadCostRead(SQLModel):
    id: UUID
    cost_category_id: UUID
    fund_account_id: UUID | None
    amount: int
    date: date
    note: str | None
    month: str


class OverheadAllocationItemInput(SQLModel):
    project_id: UUID
    allocated_amount: int


class OverheadManualAllocationRequest(SQLModel):
    month: str
    items: list[OverheadAllocationItemInput]


class OverheadAllocationRead(SQLModel):
    id: UUID
    month: str
    project_id: UUID
    revenue_share: float
    allocated_amount: int
