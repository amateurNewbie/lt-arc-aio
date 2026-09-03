from datetime import date
from uuid import UUID, uuid4

from sqlalchemy import JSON, Column
from sqlmodel import Field, SQLModel

from app.models.enums import EmployeeStatus


class Employee(SQLModel, table=True):
    """FR-14 — hồ sơ nhân sự cơ bản (không đính kèm giấy tờ)."""

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    user_id: UUID = Field(foreign_key="user.id", unique=True, index=True)
    phone: str | None = Field(default=None)
    hire_date: date | None = Field(default=None)
    status: EmployeeStatus = Field(default=EmployeeStatus.ACTIVE)

    pay_profile_id: UUID | None = Field(default=None, foreign_key="payprofile.id")
    daily_rate_override: int | None = Field(default=None)
    allowance_overrides: list[dict] | None = Field(default=None, sa_column=Column(JSON))
