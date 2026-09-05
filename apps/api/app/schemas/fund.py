from datetime import date as date_type
from datetime import datetime
from uuid import UUID

from sqlmodel import SQLModel

from app.models.enums import FundType


class FundAccountCreate(SQLModel):
    name: str
    type: FundType
    balance: int = 0


class FundAccountRead(SQLModel):
    id: UUID
    name: str
    type: FundType
    balance: int


class CashLedgerEntryRead(SQLModel):
    id: UUID
    fund_account_id: UUID
    date: date_type
    description: str
    inflow: int
    outflow: int
    source_type: str
    source_id: UUID
    created_at: datetime
