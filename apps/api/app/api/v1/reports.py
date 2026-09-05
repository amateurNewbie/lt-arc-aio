from fastapi import APIRouter, Depends

from app.core.deps import get_session, require_roles
from app.core.permissions import Role
from app.schemas.reports import CashflowReport, MonthlyPnl, ProjectPnl
from app.services.pnl_service import all_projects_pnl, cashflow_report, monthly_pnl
from sqlmodel.ext.asyncio.session import AsyncSession

router = APIRouter(prefix="/api/reports", tags=["reports"])


@router.get("/cashflow", response_model=CashflowReport)
async def cashflow_report_endpoint(
    year: int,
    month: int,
    session: AsyncSession = Depends(get_session),
    _user=Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> dict:
    """FR-12.4 — báo cáo dòng tiền theo tháng."""
    return await cashflow_report(session, year, month)


@router.get("/profit-loss", response_model=list[ProjectPnl])
async def profit_loss_endpoint(
    session: AsyncSession = Depends(get_session),
    _user=Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> list[dict]:
    """FR-11.3 — báo cáo Lãi/Lỗ tổng hợp nhiều dự án."""
    return await all_projects_pnl(session)


@router.get("/profit-loss/monthly", response_model=MonthlyPnl)
async def monthly_profit_loss_endpoint(
    year: int,
    month: int,
    session: AsyncSession = Depends(get_session),
    _user=Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> dict:
    """FR-11.5 — báo cáo Lãi/Lỗ theo từng tháng toàn studio."""
    return await monthly_pnl(session, year, month)
