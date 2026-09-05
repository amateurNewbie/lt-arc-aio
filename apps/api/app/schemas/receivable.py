from datetime import date
from uuid import UUID

from sqlmodel import SQLModel

from app.models.enums import MilestoneStatus


class ReceivableRead(SQLModel):
    milestone_id: UUID
    contract_id: UUID
    project_id: UUID
    milestone_name: str
    amount: int
    paid_amount: int
    remaining: int
    due_date: date | None
    status: MilestoneStatus
