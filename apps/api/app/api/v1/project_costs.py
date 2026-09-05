from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.deps import get_current_user, get_session, require_project_finance_write
from app.core.permissions import PermissionGroup
from app.models.project_cost import ProjectCost
from app.models.user import User
from app.schemas.project_cost import DuplicateCostWarningResponse, ProjectCostCreate, ProjectCostRead
from app.services.project_cost_service import DuplicateCostWarning, InvalidCostCategoryError, create_cost, list_by_project

router = APIRouter(prefix="/api/projects/{project_id}/costs", tags=["project-costs"])


@router.get("", response_model=list[ProjectCostRead])
async def list_costs_endpoint(
    project_id: UUID,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(get_current_user),
) -> list[ProjectCost]:
    """FR-6.4 — sổ Thu & Chi (phần Chi) theo dự án."""
    return await list_by_project(session, project_id)


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_cost_endpoint(
    project_id: UUID,
    payload: ProjectCostCreate,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(require_project_finance_write(PermissionGroup.PROJECT_CASHBOOK)),
):
    """FR-6.2/6.6 — Chi bắt buộc gắn hạng mục chi phí; cảnh báo trùng trước khi lưu."""
    try:
        cost = await create_cost(
            session,
            project_id=project_id,
            cost_category_id=payload.cost_category_id,
            amount=payload.amount,
            actor=user,
            on=payload.date,
            note=payload.note,
            work_item_id=payload.work_item_id,
            confirm_duplicate=payload.confirm_duplicate,
        )
    except InvalidCostCategoryError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc)) from exc
    except DuplicateCostWarning as exc:
        return DuplicateCostWarningResponse(
            existing_cost_id=exc.existing.id,
            existing_amount=exc.existing.amount,
            existing_date=exc.existing.date,
        )
    return ProjectCostRead(**cost.model_dump())
