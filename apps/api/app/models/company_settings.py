from uuid import UUID, uuid4

from sqlmodel import Field, SQLModel


class CompanySettings(SQLModel, table=True):
    """FR-20 — thông tin chung của studio (bản ghi duy nhất)."""

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    name: str
    owner: str | None = Field(default=None)
    phone: str | None = Field(default=None)
    email: str | None = Field(default=None)
    currency: str = Field(default="VND")
    unit: str = Field(default="m2")

    # FR-19.2 — số ngày nhắc trước, cấu hình được.
    task_reminder_days: int = Field(default=1)
    debt_reminder_days: int = Field(default=3)
    overhead_reminder_day: int = Field(default=28)  # FR-8.4 — ngày trong tháng
