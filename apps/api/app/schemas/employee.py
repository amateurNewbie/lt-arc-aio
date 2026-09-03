from datetime import date
from uuid import UUID

from sqlmodel import SQLModel

from app.models.enums import EmployeeStatus


class EmployeeCreate(SQLModel):
    user_id: UUID
    phone: str | None = None
    hire_date: date | None = None
    pay_profile_id: UUID | None = None


class EmployeeRead(SQLModel):
    id: UUID
    user_id: UUID
    phone: str | None
    hire_date: date | None
    status: EmployeeStatus
    pay_profile_id: UUID | None
