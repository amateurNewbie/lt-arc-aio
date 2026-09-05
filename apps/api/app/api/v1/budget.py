from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.deps import get_current_user, get_session, require_roles
from app.core.permissions import Role
from app.models.budget import BudgetEstimate
from app.models.user import User
from app.schemas.budget import BudgetEstimateCreate, BudgetEstimateLineRead, BudgetEstimateRead
from app.services.budget_service import (
    InvalidBudgetTransitionError,
    approve,
    create_draft,
    get_lines,
    list_by_project,
    submit,
)

router = APIRouter(prefix="/api/projects/{project_id}/budget", tags=["budget"])


async def _to_read(session: AsyncSession, budget: BudgetEstimate) -> BudgetEstimateRead:
    lines = await get_lines(session, budget.id)
    return BudgetEstimateRead(
        id=budget.id,
        project_id=budget.project_id,
        version=budget.version,
        status=budget.status,
        approved_by_id=budget.approved_by_id,
        total=sum(l.amount for l in lines),
        lines=[BudgetEstimateLineRead(**l.model_dump()) for l in lines],
    )


@router.get("", response_model=list[BudgetEstimateRead])
async def list_budget_endpoint(
    project_id: UUID,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(get_current_user),
) -> list[BudgetEstimateRead]:
    """FR-4.2 — mọi phiên bản dự toán của dự án, mới nhất trước."""
    budgets = await list_by_project(session, project_id)
    return [await _to_read(session, b) for b in budgets]


@router.post("", response_model=BudgetEstimateRead, status_code=status.HTTP_201_CREATED)
async def create_budget_endpoint(
    project_id: UUID,
    payload: BudgetEstimateCreate,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR, Role.DEPARTMENT_HEAD)),
) -> BudgetEstimateRead:
    """FR-4.1 — Trưởng bộ phận chỉ lập ở trạng thái Nháp (chưa gửi duyệt)."""
    budget = await create_draft(session, project_id=project_id, lines=[line.model_dump() for line in payload.lines])
    return await _to_read(session, budget)


@router.post("/{budget_id}/submit", response_model=BudgetEstimateRead)
async def submit_budget_endpoint(
    project_id: UUID,
    budget_id: UUID,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR, Role.DEPARTMENT_HEAD)),
) -> BudgetEstimateRead:
    budget = await session.get(BudgetEstimate, budget_id)
    if budget is None or budget.project_id != project_id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Budget not found")
    try:
        budget = await submit(session, budget, user)
    except InvalidBudgetTransitionError as exc:
        raise HTTPException(status.HTTP_409_CONFLICT, str(exc)) from exc
    return await _to_read(session, budget)


@router.post("/{budget_id}/approve", response_model=BudgetEstimateRead)
async def approve_budget_endpoint(
    project_id: UUID,
    budget_id: UUID,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> BudgetEstimateRead:
    """FR-4.2 — chỉ Admin/Giám đốc duyệt, không có ngưỡng tự duyệt."""
    budget = await session.get(BudgetEstimate, budget_id)
    if budget is None or budget.project_id != project_id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Budget not found")
    try:
        budget = await approve(session, budget, user)
    except InvalidBudgetTransitionError as exc:
        raise HTTPException(status.HTTP_409_CONFLICT, str(exc)) from exc
    return await _to_read(session, budget)
