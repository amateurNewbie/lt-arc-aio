from datetime import date as date_type
from uuid import UUID

from sqlmodel import SQLModel


class PaymentCreate(SQLModel):
    """Thu trên dự án — tự do hoặc gắn đợt HĐ."""

    project_id: UUID
    amount: int
    fund_account_id: UUID
    date: date_type | None = None
    note: str | None = None
    contract_milestone_id: UUID | None = None


class PaymentRead(SQLModel):
    id: UUID
    project_id: UUID
    contract_milestone_id: UUID | None
    amount: int
    date: date_type
    note: str | None = None
    fund_account_id: UUID
    recorded_by_id: UUID
