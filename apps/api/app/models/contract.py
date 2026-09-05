from datetime import date
from uuid import UUID, uuid4

from sqlalchemy import BigInteger
from sqlmodel import Field, SQLModel

from app.models.enums import ContractStatus, MilestoneStatus, ProjectCategory


class Contract(SQLModel, table=True):
    """FR-9.1 — hợp đồng gắn với một dự án."""

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    project_id: UUID = Field(foreign_key="project.id", index=True)
    code: str = Field(unique=True, index=True)
    type: ProjectCategory
    value: int = Field(sa_type=BigInteger)  # BIGINT VND
    signed_date: date | None = Field(default=None)
    due_date: date | None = Field(default=None)
    status: ContractStatus = Field(default=ContractStatus.ACTIVE, index=True)


class ContractMilestone(SQLModel, table=True):
    """FR-9.2 — đợt thanh toán của hợp đồng (kể cả khoản giữ bảo hành)."""

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    contract_id: UUID = Field(foreign_key="contract.id", index=True)
    name: str
    condition: str | None = Field(default=None)
    ratio: float  # % trên giá trị hợp đồng
    amount: int = Field(sa_type=BigInteger)  # BIGINT VND
    paid_amount: int = Field(default=0, sa_type=BigInteger)  # BIGINT VND
    due_date: date | None = Field(default=None)
    status: MilestoneStatus = Field(default=MilestoneStatus.PENDING, index=True)
    is_retention: bool = Field(default=False)
