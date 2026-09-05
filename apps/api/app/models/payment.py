from datetime import date as date_type
from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import BigInteger
from sqlmodel import Field, SQLModel

from app.core.clock import utcnow


class Payment(SQLModel, table=True):
    """FR-6.2/9.3 — khoản THU của dự án, bắt buộc gắn một đợt thanh toán hợp đồng."""

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    project_id: UUID = Field(foreign_key="project.id", index=True)
    contract_milestone_id: UUID = Field(foreign_key="contractmilestone.id", index=True)
    amount: int = Field(sa_type=BigInteger)  # BIGINT VND
    date: date_type = Field(default_factory=lambda: utcnow().date())
    fund_account_id: UUID = Field(foreign_key="fundaccount.id")
    recorded_by_id: UUID = Field(foreign_key="user.id")
    created_at: datetime = Field(default_factory=utcnow)
