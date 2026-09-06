from datetime import date
from uuid import UUID

from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.models.enums import ProjectCategory
from app.models.fund import CashLedgerEntry
from app.models.overhead import OverheadAllocation, OverheadCost
from app.models.payment import Payment
from app.models.project import Project
from app.models.project_cost import ProjectCost


def _margin(revenue: int, profit: int) -> float:
    return round(profit / revenue * 100, 2) if revenue else 0.0


def _in_range(d: date, date_from: date | None, date_to: date | None) -> bool:
    if date_from is not None and d < date_from:
        return False
    if date_to is not None and d > date_to:
        return False
    return True


async def project_pnl(
    session: AsyncSession,
    project_id: UUID,
    *,
    date_from: date | None = None,
    date_to: date | None = None,
) -> dict:
    """Lãi/Lỗ = Doanh thu đã thu − (Chi phí trực tiếp + Chi phí chung phân bổ)."""
    project = await session.get(Project, project_id)

    payments = list((await session.exec(select(Payment).where(Payment.project_id == project_id))).all())
    costs = list((await session.exec(select(ProjectCost).where(ProjectCost.project_id == project_id))).all())
    if date_from is not None or date_to is not None:
        payments = [p for p in payments if _in_range(p.date, date_from, date_to)]
        costs = [c for c in costs if _in_range(c.date, date_from, date_to)]

    revenue = sum(p.amount for p in payments)
    direct_cost = sum(c.amount for c in costs)

    overhead_q = select(OverheadAllocation).where(OverheadAllocation.project_id == project_id)
    allocations = list((await session.exec(overhead_q)).all())
    if date_from is not None or date_to is not None:
        filtered = []
        for a in allocations:
            try:
                y, m = a.month.split("-")
                month_day = date(int(y), int(m), 1)
            except ValueError:
                continue
            if _in_range(month_day, date_from, date_to):
                filtered.append(a)
        allocations = filtered
    overhead = sum(a.allocated_amount for a in allocations)

    total_cost = direct_cost + overhead
    profit = revenue - total_cost

    return {
        "project_id": project_id,
        "project_code": project.code,
        "project_name": project.name,
        "revenue": revenue,
        "direct_cost": direct_cost,
        "overhead_allocated": overhead,
        "total_cost": total_cost,
        "profit": profit,
        "margin_percent": _margin(revenue, profit),
    }


async def all_projects_pnl(
    session: AsyncSession,
    *,
    category: ProjectCategory | None = None,
    project_id: UUID | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
) -> list[dict]:
    query = select(Project)
    if category is not None:
        query = query.where(Project.category == category)
    if project_id is not None:
        query = query.where(Project.id == project_id)
    result = await session.exec(query)
    return [await project_pnl(session, p.id, date_from=date_from, date_to=date_to) for p in result.all()]


def _same_month(d, year: int, month: int) -> bool:
    return d.year == year and d.month == month


async def monthly_pnl(session: AsyncSession, year: int, month: int) -> dict:
    payments = (await session.exec(select(Payment))).all()
    costs = (await session.exec(select(ProjectCost))).all()
    overheads = (await session.exec(select(OverheadCost))).all()

    month_key = f"{year:04d}-{month:02d}"
    revenue = sum(p.amount for p in payments if _same_month(p.date, year, month))
    direct_cost = sum(c.amount for c in costs if _same_month(c.date, year, month))
    overhead_cost = sum(o.amount for o in overheads if o.month == month_key)
    total_cost = direct_cost + overhead_cost
    profit = revenue - total_cost

    return {
        "month": month_key,
        "revenue": revenue,
        "direct_cost": direct_cost,
        "overhead_cost": overhead_cost,
        "total_cost": total_cost,
        "profit": profit,
        "margin_percent": _margin(revenue, profit),
    }


async def cashflow_report(session: AsyncSession, year: int, month: int) -> dict:
    entries = (await session.exec(select(CashLedgerEntry))).all()
    month_key = f"{year:04d}-{month:02d}"

    before = [e for e in entries if (e.date.year, e.date.month) < (year, month)]
    this_month = [e for e in entries if _same_month(e.date, year, month)]

    opening = sum(e.inflow - e.outflow for e in before)
    total_inflow = sum(e.inflow for e in this_month)
    total_outflow = sum(e.outflow for e in this_month)

    return {
        "month": month_key,
        "opening_balance": opening,
        "total_inflow": total_inflow,
        "total_outflow": total_outflow,
        "closing_balance": opening + total_inflow - total_outflow,
    }
