from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import BigInteger
from sqlmodel import Field, SQLModel

from app.core.clock import utcnow
from app.models.enums import BudgetEstimateStatus


class BudgetEstimate(SQLModel, table=True):
    """FR-4 — dự toán của một dự án, theo phiên bản."""

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    project_id: UUID = Field(foreign_key="project.id", index=True)
    version: int = Field(default=1)
    status: BudgetEstimateStatus = Field(default=BudgetEstimateStatus.DRAFT, index=True)
    approved_by_id: UUID | None = Field(default=None, foreign_key="user.id")
    approved_at: datetime | None = Field(default=None)
    created_at: datetime = Field(default_factory=utcnow)


class BudgetEstimateLine(SQLModel, table=True):
    """FR-4.1 — từng dòng dự toán theo hạng mục chi phí."""

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    budget_estimate_id: UUID = Field(foreign_key="budgetestimate.id", index=True)
    cost_category_id: UUID = Field(foreign_key="costcategory.id")
    description: str | None = Field(default=None)
    unit: str
    quantity: float
    unit_price: int = Field(sa_type=BigInteger)  # BIGINT VND
    amount: int = Field(sa_type=BigInteger)  # BIGINT VND — quantity * unit_price, tính ở service
