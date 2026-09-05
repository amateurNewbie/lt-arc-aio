from datetime import datetime
from uuid import UUID, uuid4

from sqlmodel import Field, SQLModel, UniqueConstraint

from app.core.clock import utcnow


class MonthlyWorkDays(SQLModel, table=True):
    """FR-15 — số ngày công thực tế nhập cuối tháng cho từng nhân viên."""

    __table_args__ = (UniqueConstraint("employee_id", "month", name="uq_workdays_employee_month"),)

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    employee_id: UUID = Field(foreign_key="employee.id", index=True)
    month: str = Field(index=True)  # "YYYY-MM"
    actual_days: float
    entered_by_id: UUID = Field(foreign_key="user.id")
    locked_at: datetime | None = Field(default=None)
    updated_at: datetime = Field(default_factory=utcnow)
