from datetime import date as date_type
from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import BigInteger
from sqlmodel import Field, SQLModel

from app.core.clock import utcnow


class ProjectCost(SQLModel, table=True):
    """FR-6.2 — khoản CHI của dự án, bắt buộc gắn hạng mục chi phí (scope=PROJECT)."""

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    project_id: UUID = Field(foreign_key="project.id", index=True)
    cost_category_id: UUID = Field(foreign_key="costcategory.id", index=True)
    work_item_id: UUID | None = Field(default=None, foreign_key="workitem.id")
    fund_account_id: UUID | None = Field(default=None, foreign_key="fundaccount.id")
    """FR-12 — quỹ thực chi; ghi sổ quỹ khi có."""
    amount: int = Field(sa_type=BigInteger)  # BIGINT VND
    date: date_type = Field(default_factory=lambda: utcnow().date())
    note: str | None = Field(default=None)
    recorded_by_id: UUID = Field(foreign_key="user.id")
    created_at: datetime = Field(default_factory=utcnow)
