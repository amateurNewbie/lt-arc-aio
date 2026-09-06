from datetime import date, timedelta
from uuid import UUID

from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.clock import utcnow
from app.models.cost_category import CostCategory
from app.models.enums import CostCategoryScope
from app.models.fund import CashLedgerEntry, FundAccount
from app.models.project_cost import ProjectCost
from app.models.user import User
from app.services.activity_service import log_activity


class InvalidCostCategoryError(Exception):
    pass


class DuplicateCostWarning(Exception):
    """FR-6.6 — cảnh báo trùng, chưa lưu; gọi lại với confirm_duplicate=True để lưu."""

    def __init__(self, existing: ProjectCost):
        self.existing = existing
        super().__init__("Possible duplicate cost entry")


async def _find_duplicate(session: AsyncSession, *, project_id: UUID, cost_category_id: UUID, amount: int, on: date) -> ProjectCost | None:
    window_start = on - timedelta(days=3)
    window_end = on + timedelta(days=3)
    result = await session.exec(
        select(ProjectCost).where(
            ProjectCost.project_id == project_id,
            ProjectCost.cost_category_id == cost_category_id,
            ProjectCost.amount == amount,
            ProjectCost.date >= window_start,
            ProjectCost.date <= window_end,
        )
    )
    return result.first()


async def create_cost(
    session: AsyncSession,
    *,
    project_id: UUID,
    cost_category_id: UUID,
    amount: int,
    actor: User,
    on: date | None = None,
    note: str | None = None,
    work_item_id: UUID | None = None,
    fund_account_id: UUID | None = None,
    confirm_duplicate: bool = False,
) -> ProjectCost:
    """FR-6.2/FR-12 — CHI gắn hạng mục PROJECT; nếu có quỹ thì ghi sổ quỹ (outflow)."""
    category = await session.get(CostCategory, cost_category_id)
    if category is None or category.scope != CostCategoryScope.PROJECT:
        raise InvalidCostCategoryError("Hạng mục chi phí phải thuộc phạm vi Chi phí dự án")

    cost_date = on or utcnow().date()

    if not confirm_duplicate:
        existing = await _find_duplicate(session, project_id=project_id, cost_category_id=cost_category_id, amount=amount, on=cost_date)
        if existing is not None:
            raise DuplicateCostWarning(existing)

    fund: FundAccount | None = None
    if fund_account_id is not None:
        fund = await session.get(FundAccount, fund_account_id)
        if fund is None:
            raise ValueError("Fund account not found")

    cost = ProjectCost(
        project_id=project_id,
        cost_category_id=cost_category_id,
        work_item_id=work_item_id,
        fund_account_id=fund_account_id,
        amount=amount,
        date=cost_date,
        note=note,
        recorded_by_id=actor.id,
    )
    session.add(cost)
    await session.flush()

    if fund is not None:
        session.add(
            CashLedgerEntry(
                fund_account_id=fund.id,
                date=cost_date,
                description=note or f"Chi dự án — {category.name}",
                inflow=0,
                outflow=amount,
                source_type="project_cost",
                source_id=cost.id,
                recorded_by_id=actor.id,
            )
        )
        fund.balance -= amount
        session.add(fund)

    await session.commit()
    await session.refresh(cost)

    await log_activity(session, icon="coins", title=f"Ghi nhận chi phí {amount:,} ₫", user_id=actor.id, project_id=project_id)
    return cost


async def list_by_project(session: AsyncSession, project_id: UUID) -> list[ProjectCost]:
    result = await session.exec(select(ProjectCost).where(ProjectCost.project_id == project_id).order_by(ProjectCost.date.desc()))
    return list(result.all())


async def total_by_category(session: AsyncSession, project_id: UUID) -> dict[UUID, int]:
    """FR-6.3 — tổng chi phí thực tế theo từng hạng mục, để đối chiếu dự toán."""
    costs = await list_by_project(session, project_id)
    totals: dict[UUID, int] = {}
    for cost in costs:
        totals[cost.cost_category_id] = totals.get(cost.cost_category_id, 0) + cost.amount
    return totals
