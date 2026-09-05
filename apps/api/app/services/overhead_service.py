from datetime import date

from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.models.cost_category import CostCategory
from app.models.enums import AllocationBasis, CostCategoryScope, ProjectStatus
from app.models.overhead import OverheadAllocation, OverheadCost
from app.models.payment import Payment
from app.models.project import Project
from app.models.user import User
from app.services.activity_service import log_activity


class InvalidOverheadCategoryError(Exception):
    pass


class AllocationAlreadyAppliedError(Exception):
    pass


async def declare_cost(
    session: AsyncSession,
    *,
    cost_category_id: str,
    amount: int,
    on: date,
    month: str,
    note: str | None = None,
) -> OverheadCost:
    """FR-8.1 — chi phí chung công ty, không gắn dự án cụ thể."""
    category = await session.get(CostCategory, cost_category_id)
    if category is None or category.scope != CostCategoryScope.COMPANY:
        raise InvalidOverheadCategoryError("Hạng mục chi phí phải thuộc phạm vi Chi phí chung công ty")

    cost = OverheadCost(cost_category_id=cost_category_id, amount=amount, date=on, month=month, note=note)
    session.add(cost)
    await session.commit()
    await session.refresh(cost)
    return cost


async def _month_total_overhead(session: AsyncSession, month: str) -> int:
    result = await session.exec(select(OverheadCost).where(OverheadCost.month == month))
    return sum(c.amount for c in result.all())


async def _project_revenue_in_month(session: AsyncSession, month: str) -> dict:
    """Doanh thu (tổng Payment) từng dự án trong tháng — chỉ tính dự án có thu > 0."""
    year, mon = month.split("-")
    result = await session.exec(select(Payment))
    revenue: dict = {}
    for payment in result.all():
        if f"{payment.date.year:04d}-{payment.date.month:02d}" == f"{year}-{mon}":
            revenue[payment.project_id] = revenue.get(payment.project_id, 0) + payment.amount
    return revenue


async def _compute_allocation(session: AsyncSession, month: str, basis: AllocationBasis) -> list[dict]:
    """FR-8.2 — công thức theo doanh thu (mặc định) hoặc chia đều."""
    total_overhead = await _month_total_overhead(session, month)
    if total_overhead == 0:
        return []

    if basis == AllocationBasis.REVENUE:
        revenue_by_project = await _project_revenue_in_month(session, month)
        total_revenue = sum(revenue_by_project.values())
        if total_revenue == 0:
            return []
        items = []
        for project_id, revenue in revenue_by_project.items():
            share = revenue / total_revenue
            project = await session.get(Project, project_id)
            items.append(
                {
                    "project_id": project_id,
                    "project_code": project.code,
                    "revenue_share": share,
                    "allocated_amount": round(total_overhead * share),
                }
            )
        return items

    # EQUAL — chia đều theo số dự án đang hoạt động (status IN_PROGRESS) trong tháng
    result = await session.exec(select(Project).where(Project.status == ProjectStatus.IN_PROGRESS))
    active_projects = result.all()
    if not active_projects:
        return []
    share_amount = round(total_overhead / len(active_projects))
    return [
        {
            "project_id": p.id,
            "project_code": p.code,
            "revenue_share": 0.0,
            "allocated_amount": share_amount,
        }
        for p in active_projects
    ]


async def preview_allocation(session: AsyncSession, month: str, basis: AllocationBasis) -> list[dict]:
    """FR-8.3 bước 1 — XEM TRƯỚC, không ghi DB."""
    return await _compute_allocation(session, month, basis)


async def apply_allocation(session: AsyncSession, month: str, basis: AllocationBasis, actor: User) -> list[OverheadAllocation]:
    """FR-8.3 bước 2 — XÁC NHẬN & ÁP DỤNG; idempotent theo tháng (không tính trùng)."""
    existing = await session.exec(select(OverheadAllocation).where(OverheadAllocation.month == month))
    if existing.first() is not None:
        raise AllocationAlreadyAppliedError(f"Tháng {month} đã được phân bổ trước đó")

    items = await _compute_allocation(session, month, basis)
    allocations = []
    for item in items:
        allocation = OverheadAllocation(
            month=month,
            project_id=item["project_id"],
            revenue_share=item["revenue_share"],
            allocated_amount=item["allocated_amount"],
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
