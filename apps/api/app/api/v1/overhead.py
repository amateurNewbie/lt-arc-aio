from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.deps import get_session, require_perm
from app.core.permissions import PermissionGroup
from app.models.enums import ProjectStatus
from app.models.overhead import OverheadAllocation, OverheadCost
from app.models.project import Project
from app.models.user import User
from app.schemas.overhead import (
    OverheadAllocationRead,
    OverheadCostCreate,
    OverheadCostRead,
    OverheadManualAllocationRequest,
)
from app.services.overhead_service import (
    AllocationAlreadyAppliedError,
    InvalidOverheadCategoryError,
    OverheadAllocationMismatchError,
    apply_manual_allocation,
    declare_cost,
    list_allocations,
)

router = APIRouter(prefix="/api/overhead-costs", tags=["overhead"])


@router.get("", response_model=list[OverheadCostRead])
async def list_overhead_costs_endpoint(
    month: str | None = None,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(require_perm(PermissionGroup.OVERHEAD_ALLOCATE)),
) -> list[OverheadCost]:
    query = select(OverheadCost)
    if month is not None:
        query = query.where(OverheadCost.month == month)
    result = await session.exec(query.order_by(OverheadCost.date.desc()))
    return list(result.all())


@router.post("", response_model=OverheadCostRead, status_code=status.HTTP_201_CREATED)
async def create_overhead_cost_endpoint(
    payload: OverheadCostCreate,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(require_perm(PermissionGroup.OVERHEAD_ALLOCATE)),
) -> OverheadCost:
    try:
        return await declare_cost(
            session,
            cost_category_id=payload.cost_category_id,
            amount=payload.amount,
            on=payload.date,
            month=payload.month,
            fund_account_id=payload.fund_account_id,
            actor=user,
            note=payload.note,
        )
    except InvalidOverheadCategoryError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc)) from exc


@router.get("/active-projects")
async def list_active_projects_for_allocation(
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(require_perm(PermissionGroup.OVERHEAD_ALLOCATE)),
) -> list[dict]:
    result = await session.exec(
        select(Project).where(
            Project.status.in_(
                [ProjectStatus.PLANNING, ProjectStatus.IN_PROGRESS, ProjectStatus.AWAITING_FEEDBACK]
            )
        )
    )
    return [
        {"project_id": str(p.id), "project_code": p.code, "project_name": p.name, "status": p.status.value}
        for p in result.all()
    ]


@router.post("/allocate", response_model=list[OverheadAllocationRead], status_code=status.HTTP_201_CREATED)
async def apply_manual_allocation_endpoint(
    payload: OverheadManualAllocationRequest,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(require_perm(PermissionGroup.OVERHEAD_ALLOCATE)),
) -> list[OverheadAllocation]:
    try:
        return await apply_manual_allocation(
            session,
            month=payload.month,
            items=[{"project_id": i.project_id, "allocated_amount": i.allocated_amount} for i in payload.items],
            actor=user,
        )
    except AllocationAlreadyAppliedError as exc:
        raise HTTPException(status.HTTP_409_CONFLICT, str(exc)) from exc
    except OverheadAllocationMismatchError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc)) from exc


@router.get("/allocations", response_model=list[OverheadAllocationRead])
async def list_allocations_endpoint(
    month: str | None = None,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(require_perm(PermissionGroup.OVERHEAD_ALLOCATE)),
) -> list[OverheadAllocation]:
    return await list_allocations(session, month)
