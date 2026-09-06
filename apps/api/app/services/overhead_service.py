from datetime import date
from uuid import UUID

from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.models.cost_category import CostCategory
from app.models.enums import CostCategoryScope
from app.models.fund import CashLedgerEntry, FundAccount
from app.models.overhead import OverheadAllocation, OverheadCost
from app.models.user import User
from app.services.activity_service import log_activity


class InvalidOverheadCategoryError(Exception):
    pass


class AllocationAlreadyAppliedError(Exception):
    pass


class OverheadAllocationMismatchError(Exception):
    pass


async def declare_cost(
    session: AsyncSession,
    *,
    cost_category_id: UUID,
    amount: int,
    on: date,
    month: str,
    fund_account_id: UUID,
    actor: User,
    note: str | None = None,
) -> OverheadCost:
    """Chi phí chung công ty + ghi sổ quỹ (outflow)."""
    category = await session.get(CostCategory, cost_category_id)
    if category is None or category.scope != CostCategoryScope.COMPANY:
        raise InvalidOverheadCategoryError("Hạng mục chi phí phải thuộc phạm vi Chi phí chung công ty")

    fund = await session.get(FundAccount, fund_account_id)
    if fund is None:
        raise ValueError("Fund account not found")

    cost = OverheadCost(
        cost_category_id=cost_category_id,
        fund_account_id=fund_account_id,
        amount=amount,
        date=on,
        month=month,
        note=note,
    )
    session.add(cost)
    await session.flush()

    session.add(
        CashLedgerEntry(
            fund_account_id=fund_account_id,
            date=on,
            description=note or f"Chi phí chung — {category.name}",
            inflow=0,
            outflow=amount,
            source_type="overhead_cost",
            source_id=cost.id,
            recorded_by_id=actor.id,
        )
    )
    fund.balance -= amount
    session.add(fund)

    await session.commit()
    await session.refresh(cost)

    await log_activity(
        session,
        icon="building",
        title=f"Chi phí chung {amount:,} ₫ — {category.name}",
        user_id=actor.id,
    )
    return cost


async def _month_total_overhead(session: AsyncSession, month: str) -> int:
    result = await session.exec(select(OverheadCost).where(OverheadCost.month == month))
    return sum(c.amount for c in result.all())


async def apply_manual_allocation(
    session: AsyncSession,
    *,
    month: str,
    items: list[dict],
    actor: User,
) -> list[OverheadAllocation]:
    """Phân bổ tay: tổng allocated_amount phải = tổng chi phí chung tháng."""
    existing = await session.exec(select(OverheadAllocation).where(OverheadAllocation.month == month))
    if existing.first() is not None:
        raise AllocationAlreadyAppliedError(f"Tháng {month} đã được phân bổ trước đó")

    total_overhead = await _month_total_overhead(session, month)
    if total_overhead <= 0:
        raise OverheadAllocationMismatchError("Tháng này chưa có chi phí chung để phân bổ")

    cleaned = [i for i in items if int(i.get("allocated_amount") or 0) > 0]
    allocated_sum = sum(int(i["allocated_amount"]) for i in cleaned)
    if allocated_sum != total_overhead:
        raise OverheadAllocationMismatchError(
            f"Tổng phân bổ ({allocated_sum:,}) phải bằng tổng chi phí chung tháng ({total_overhead:,})"
        )

    allocations: list[OverheadAllocation] = []
    for item in cleaned:
        amount = int(item["allocated_amount"])
        share = (amount / total_overhead) if total_overhead else 0.0
        allocation = OverheadAllocation(
            month=month,
            project_id=item["project_id"],
            revenue_share=share,
            allocated_amount=amount,
        )
        session.add(allocation)
        allocations.append(allocation)

    await session.commit()
    for allocation in allocations:
        await session.refresh(allocation)
    await log_activity(session, icon="split", title=f"Phân bổ chi phí chung tháng {month}", user_id=actor.id)
    return allocations


async def list_allocations(session: AsyncSession, month: str | None = None) -> list[OverheadAllocation]:
    query = select(OverheadAllocation)
    if month is not None:
        query = query.where(OverheadAllocation.month == month)
    result = await session.exec(query)
    return list(result.all())
