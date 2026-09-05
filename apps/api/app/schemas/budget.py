from uuid import UUID

from sqlmodel import SQLModel

from app.models.enums import BudgetEstimateStatus


class BudgetEstimateLineCreate(SQLModel):
    cost_category_id: UUID
    description: str | None = None
    unit: str
    quantity: float
    unit_price: int


class BudgetEstimateCreate(SQLModel):
    lines: list[BudgetEstimateLineCreate]


class BudgetEstimateLineRead(SQLModel):
    id: UUID
    cost_category_id: UUID
    description: str | None
    unit: str
    quantity: float
    unit_price: int
    amount: int


class BudgetEstimateRead(SQLModel):
    id: UUID
    project_id: UUID
    version: int
    status: BudgetEstimateStatus
    approved_by_id: UUID | None
    total: int
    lines: list[BudgetEstimateLineRead]
