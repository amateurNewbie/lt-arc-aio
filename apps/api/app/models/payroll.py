from uuid import UUID, uuid4

from sqlalchemy import JSON, BigInteger, Column, UniqueConstraint
from sqlmodel import Field, SQLModel

from app.models.enums import PayrollStatus


class PayrollRecord(SQLModel, table=True):
    """FR-16.2/16.6 — bảng lương theo tháng, lưu snapshot đơn giá/phụ cấp đã dùng."""

    __table_args__ = (UniqueConstraint("employee_id", "month", name="uq_payroll_employee_month"),)

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    employee_id: UUID = Field(foreign_key="employee.id", index=True)
    month: str = Field(index=True)  # "YYYY-MM"
    daily_rate: int = Field(sa_type=BigInteger)  # BIGINT VND — snapshot lúc chạy lương
    actual_days: float
    day_wage: int = Field(sa_type=BigInteger)  # BIGINT VND = actual_days * daily_rate
    allowances: list[dict] = Field(default_factory=list, sa_column=Column(JSON))
    net_pay: int = Field(sa_type=BigInteger)  # BIGINT VND = day_wage + sum(allowances)
    status: PayrollStatus = Field(default=PayrollStatus.UNPAID, index=True)
