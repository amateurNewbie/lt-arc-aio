from datetime import date as date_type
from uuid import UUID, uuid4

from sqlalchemy import BigInteger
from sqlmodel import Field, SQLModel, UniqueConstraint


class OverheadCost(SQLModel, table=True):
    """FR-8.1 — chi phí chung công ty theo tháng, không gắn dự án cụ thể."""

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    cost_category_id: UUID = Field(foreign_key="costcategory.id")
    amount: int = Field(sa_type=BigInteger)  # BIGINT VND
    date: date_type
    note: str | None = Field(default=None)
    month: str = Field(index=True)  # "YYYY-MM"


class OverheadAllocation(SQLModel, table=True):
    """FR-8.2/8.3 — kết quả phân bổ chi phí chung cho từng dự án theo tháng.

    Unique theo (month, project_id) — apply idempotent, không tính trùng.
    """

    __table_args__ = (UniqueConstraint("month", "project_id", name="uq_overhead_allocation_month_project"),)

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    month: str = Field(index=True)  # "YYYY-MM"
    project_id: UUID = Field(foreign_key="project.id", index=True)
    revenue_share: float  # tỷ trọng doanh thu dùng để tính (0 nếu chia đều)
    allocated_amount: int = Field(sa_type=BigInteger)  # BIGINT VND
