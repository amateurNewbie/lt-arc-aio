from datetime import date
from uuid import UUID, uuid4

from sqlalchemy import BigInteger
from sqlmodel import Field, SQLModel

from app.models.enums import PayableStatus


class Payable(SQLModel, table=True):
    """FR-10.2 — công nợ phải trả nhà cung cấp/thầu phụ theo dự án."""

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    project_id: UUID = Field(foreign_key="project.id", index=True)
    vendor_name: str
    cost_category_id: UUID = Field(foreign_key="costcategory.id")
    total_amount: int = Field(sa_type=BigInteger)  # BIGINT VND
    paid_amount: int = Field(default=0, sa_type=BigInteger)  # BIGINT VND
    due_date: date | None = Field(default=None)
    status: PayableStatus = Field(default=PayableStatus.PENDING, index=True)
