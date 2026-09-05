from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.deps import get_session, require_perm
from app.core.permissions import PermissionGroup
from app.models.overhead import OverheadAllocation, OverheadCost
from app.models.user import User
from app.schemas.overhead import (
    OverheadAllocationPreviewItem,
    OverheadAllocationRead,
    OverheadAllocationRequest,
    OverheadCostCreate,
    OverheadCostRead,
)
from app.services.overhead_service import (
    AllocationAlreadyAppliedError,
    InvalidOverheadCategoryError,
    apply_allocation,
    declare_cost,
    list_allocations,
    preview_allocation,
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
    result = await session.exec(query)
    return list(result.all())


@router.post("", response_model=OverheadCostRead, status_code=status.HTTP_201_CREATED)
async def create_overhead_cost_endpoint(
    payload: OverheadCostCreate,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(require_perm(PermissionGroup.OVERHEAD_ALLOCATE)),
) -> OverheadCost:
    """FR-8.1 — chi phí chung công ty theo tháng."""
    try:
        return await declare_cost(
            session,
            cost_category_id=payload.cost_category_id,
            amount=payload.amount,
            on=payload.date,
            month=payload.month,
            note=payload.note,
        )
    except InvalidOverheadCategoryError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc)) from exc


@router.post("/allocate/preview", response_model=list[OverheadAllocationPreviewItem])
async def preview_allocation_endpoint(
    payload: OverheadAllocationRequest,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(require_perm(PermissionGroup.OVERHEAD_ALLOCATE)),
) -> list[dict]:
    """FR-8.3 bước 1 — XEM TRƯỚC, không ghi DB."""
    return await preview_allocation(session, payload.month, payload.basis)


@router.post("/allocate", response_model=list[OverheadAllocationRead], status_code=status.HTTP_201_CREATED)
async def apply_allocation_endpoint(
    payload: OverheadAllocationRequest,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(require_perm(PermissionGroup.OVERHEAD_ALLOCATE)),
) -> list[OverheadAllocation]:
    """FR-8.3 bước 2 — XÁC NHẬN & ÁP DỤNG; idempotent theo tháng."""
    try:
        return await apply_allocation(session, payload.month, payload.basis, user)
    except AllocationAlreadyAppliedError as exc:
        raise HTTPException(status.HTTP_409_CONFLICT, str(exc)) from exc


@router.get("/allocations", response_model=list[OverheadAllocationRead])
async def list_allocations_endpoint(
    month: str | None = None,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(require_perm(PermissionGroup.OVERHEAD_ALLOCATE)),
) -> list[OverheadAllocation]:
    """FR-8.4 — lịch sử các lần phân bổ theo tháng."""
    return await list_allocations(session, month)
