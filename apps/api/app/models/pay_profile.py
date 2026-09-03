from uuid import UUID, uuid4

from sqlmodel import Field, SQLModel
from sqlalchemy import Column, JSON


class PayProfile(SQLModel, table=True):
    """FR-16.5 — cấu hình lương theo vai trò/chức danh."""

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    role_title: str = Field(unique=True)
    daily_rate: int  # BIGINT VND — NFR: không dùng float cho tiền
    allowances: list[dict] = Field(default_factory=list, sa_column=Column(JSON))
    """Mỗi phần tử: {"name": str, "amount": int, "taxable": bool, "tax_free_cap": int | None}."""

    active: bool = Field(default=True)
