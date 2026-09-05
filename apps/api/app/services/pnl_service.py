from uuid import UUID

from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.models.fund import CashLedgerEntry
from app.models.overhead import OverheadAllocation, OverheadCost
from app.models.payment import Payment
from app.models.project import Project
from app.models.project_cost import ProjectCost


def _margin(revenue: int, profit: int) -> float:
    return round(profit / revenue * 100, 2) if revenue else 0.0


async def project_pnl(session: AsyncSession, project_id: UUID) -> dict:
    """FR-11.2/11.3 — Lãi/Lỗ = Doanh thu đã thu − (Chi phí trực tiếp + Chi phí chung phân bổ)."""
    project = await session.get(Project, project_id)

    revenue = sum((await session.exec(select(Payment.amount).where(Payment.project_id == project_id))).all())
    direct_cost = sum((await session.exec(select(ProjectCost.amount).where(ProjectCost.project_id == project_id))).all())
    overhead = sum(
        (await session.exec(select(OverheadAllocation.allocated_amount).where(OverheadAllocation.project_id == project_id))).all()
    )
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


async def all_projects_pnl(session: AsyncSession) -> list[dict]:
    """FR-11.3 — báo cáo P&L theo từng dự án, toàn studio."""
    result = await session.exec(select(Project.id))
    return [await project_pnl(session, project_id) for project_id in result.all()]


def _same_month(d, year: int, month: int) -> bool:
    return d.year == year and d.month == month


async def monthly_pnl(session: AsyncSession, year: int, month: int) -> dict:
    """FR-11.5 — P&L toàn studio theo từng tháng."""
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
    """FR-12.4 — số dư đầu kỳ, tổng thu, tổng chi, số dư cuối kỳ."""
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
