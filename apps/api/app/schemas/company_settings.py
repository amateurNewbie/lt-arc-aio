from uuid import UUID

from sqlmodel import SQLModel


class CompanySettingsRead(SQLModel):
    id: UUID
    name: str
    owner: str | None
    phone: str | None
    email: str | None
    currency: str
    unit: str
    task_reminder_days: int
    debt_reminder_days: int
    overhead_reminder_day: int


class CompanySettingsUpdate(SQLModel):
    name: str | None = None
    owner: str | None = None
    phone: str | None = None
    email: str | None = None
    currency: str | None = None
    unit: str | None = None
    task_reminder_days: int | None = None
    debt_reminder_days: int | None = None
    overhead_reminder_day: int | None = None


class SecurityStatusItem(SQLModel):
    name: str
    active: bool
