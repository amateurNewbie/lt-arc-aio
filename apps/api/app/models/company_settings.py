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
