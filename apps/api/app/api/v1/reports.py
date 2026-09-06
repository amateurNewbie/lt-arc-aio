from datetime import date
from uuid import UUID

from fastapi import APIRouter, Depends, Query

from app.core.deps import get_session, require_roles
from app.core.permissions import Role
from app.models.enums import ProjectCategory
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
    return await cashflow_report(session, year, month)


@router.get("/profit-loss", response_model=list[ProjectPnl])
async def profit_loss_endpoint(
    session: AsyncSession = Depends(get_session),
    _user=Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
    category: ProjectCategory | None = None,
    project_id: UUID | None = None,
    date_from: date | None = Query(default=None),
    date_to: date | None = Query(default=None),
) -> list[dict]:
    return await all_projects_pnl(
        session,
        category=category,
        project_id=project_id,
        date_from=date_from,
        date_to=date_to,
    )


@router.get("/profit-loss/monthly", response_model=MonthlyPnl)
async def monthly_profit_loss_endpoint(
    year: int,
    month: int,
    session: AsyncSession = Depends(get_session),
    _user=Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> dict:
    return await monthly_pnl(session, year, month)
