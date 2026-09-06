from datetime import date as date_type
from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import BigInteger
from sqlmodel import Field, SQLModel

from app.core.clock import utcnow
from app.models.enums import FundType


class FundAccount(SQLModel, table=True):
    """FR-12.1 — quỹ tiền mặt hoặc tài khoản ngân hàng."""

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    name: str
    type: FundType
    balance: int = Field(default=0, sa_type=BigInteger)  # BIGINT VND


class CashLedgerEntry(SQLModel, table=True):
    """FR-12.2/12.3 — bút toán sổ quỹ, sinh tự động từ mọi giao dịch thu/chi."""

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    fund_account_id: UUID = Field(foreign_key="fundaccount.id", index=True)
    date: date_type = Field(default_factory=lambda: utcnow().date())
    description: str
    inflow: int = Field(default=0, sa_type=BigInteger)  # BIGINT VND
    outflow: int = Field(default=0, sa_type=BigInteger)  # BIGINT VND
    source_type: str = Field(index=True)  # "payment" | "project_cost" | "overhead_cost" | "payable_settlement" | "payroll"
    source_id: UUID
    recorded_by_id: UUID = Field(foreign_key="user.id")
    created_at: datetime = Field(default_factory=utcnow)
