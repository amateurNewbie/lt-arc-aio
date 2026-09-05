from uuid import UUID, uuid4

from sqlalchemy import BigInteger
from sqlmodel import Field, SQLModel

from app.models.enums import WorkItemStatus


class WorkItem(SQLModel, table=True):
    """FR-5.5 — hạng mục công việc (khối lượng/đơn giá), khác Task/đầu việc."""

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    project_id: UUID = Field(foreign_key="project.id", index=True)
    department_id: UUID = Field(foreign_key="department.id", index=True)
    name: str
    unit: str
    quantity: float
    unit_price: int = Field(sa_type=BigInteger)  # BIGINT VND
    amount: int = Field(sa_type=BigInteger)  # BIGINT VND — quantity * unit_price, tính ở service khi ghi
    progress: int = Field(default=0)
    status: WorkItemStatus = Field(default=WorkItemStatus.NOT_STARTED)
