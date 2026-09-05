from datetime import date as date_type
from uuid import UUID

from sqlmodel import SQLModel

from app.models.enums import PayableStatus


class PayableCreate(SQLModel):
    project_id: UUID
    vendor_name: str
    cost_category_id: UUID
    total_amount: int
    due_date: date_type | None = None


class PayableRead(SQLModel):
    id: UUID
    project_id: UUID
    vendor_name: str
    cost_category_id: UUID
    total_amount: int
    paid_amount: int
    due_date: date_type | None
    status: PayableStatus


class PayableSettleRequest(SQLModel):
    amount: int
    fund_account_id: UUID
    date: date_type | None = None
