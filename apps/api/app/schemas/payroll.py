from uuid import UUID

from sqlmodel import SQLModel

from app.models.enums import PayrollStatus


class PayrollRunRequest(SQLModel):
    month: str


class PayrollPayRequest(SQLModel):
    fund_account_id: UUID
    employee_ids: list[UUID] | None = None
    """None = trả theo lô cho toàn bộ nhân viên UNPAID của tháng (FR-16.3)."""


class PayrollRecordRead(SQLModel):
    id: UUID
    employee_id: UUID
    month: str
    daily_rate: int
    actual_days: float
    day_wage: int
    allowances: list[dict]
    net_pay: int
    status: PayrollStatus
