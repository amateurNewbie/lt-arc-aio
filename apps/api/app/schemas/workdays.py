from datetime import datetime
from uuid import UUID

from sqlmodel import SQLModel


class WorkDaysEntryInput(SQLModel):
    employee_id: UUID
    actual_days: float


class WorkDaysUpsertRequest(SQLModel):
    entries: list[WorkDaysEntryInput]


class MonthlyWorkDaysRead(SQLModel):
    id: UUID
    employee_id: UUID
    month: str
    actual_days: float
    locked_at: datetime | None
    is_over_days_in_month: bool = False
