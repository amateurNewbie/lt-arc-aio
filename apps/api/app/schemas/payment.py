from datetime import date as date_type
from uuid import UUID

from sqlmodel import SQLModel


class PaymentRead(SQLModel):
    id: UUID
    project_id: UUID
    contract_milestone_id: UUID
    amount: int
    date: date_type
    fund_account_id: UUID
    recorded_by_id: UUID
