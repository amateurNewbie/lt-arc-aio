from uuid import UUID

from sqlmodel import SQLModel


class ProjectPnl(SQLModel):
    project_id: UUID
    project_code: str
    project_name: str
    revenue: int
    direct_cost: int
    overhead_allocated: int
    total_cost: int
    profit: int
    margin_percent: float


class MonthlyPnl(SQLModel):
    month: str
    revenue: int
    direct_cost: int
    overhead_cost: int
    total_cost: int
    profit: int
    margin_percent: float


class CashflowReport(SQLModel):
    month: str
    opening_balance: int
    total_inflow: int
    total_outflow: int
    closing_balance: int
