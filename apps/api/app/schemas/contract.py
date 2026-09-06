from datetime import date as date_type
from uuid import UUID

from sqlmodel import SQLModel

from app.models.enums import ContractStatus, MilestoneStatus, ProjectCategory


class ContractMilestoneCreate(SQLModel):
    name: str
    condition: str | None = None
    ratio: float
    due_date: date_type | None = None
    is_retention: bool = False


class ContractCreate(SQLModel):
    """`project_id` trong body tuỳ chọn — endpoint path đã có project_id."""

    project_id: UUID | None = None
    type: ProjectCategory
    value: int
    signed_date: date_type | None = None
    due_date: date_type | None = None
    milestones: list[ContractMilestoneCreate]


class ContractMilestoneRead(SQLModel):
    id: UUID
    contract_id: UUID
    name: str
    condition: str | None
    ratio: float
    amount: int
    paid_amount: int
    due_date: date_type | None
    status: MilestoneStatus
    is_retention: bool


class ContractRead(SQLModel):
    id: UUID
    project_id: UUID
    code: str
    type: ProjectCategory
    value: int
    signed_date: date_type | None
    due_date: date_type | None
    status: ContractStatus
    milestones: list[ContractMilestoneRead]


class MilestoneCollectRequest(SQLModel):
    amount: int
    fund_account_id: UUID
    date: date_type | None = None
