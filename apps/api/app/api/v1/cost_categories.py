from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.deps import get_current_user, get_session, require_roles
from app.core.permissions import Role
from app.models.cost_category import CostCategory
from app.models.enums import CostCategoryScope
from app.models.user import User
from app.schemas.cost_category import CostCategoryCreate, CostCategoryRead, CostCategoryUpdate
from app.services.cost_category_service import create_category, list_categories, update_category

router = APIRouter(prefix="/api/cost-categories", tags=["cost-categories"])


@router.get("", response_model=list[CostCategoryRead])
async def list_categories_endpoint(
    scope: CostCategoryScope | None = None,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(get_current_user),
) -> list[CostCategory]:
    return await list_categories(session, scope=scope)


@router.post("", response_model=CostCategoryRead, status_code=status.HTTP_201_CREATED)
async def create_category_endpoint(
    payload: CostCategoryCreate,
    session: AsyncSession = Depends(get_session),
    _admin: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> CostCategory:
    """FR-7.1 — chỉ Admin/Giám đốc khai báo danh mục."""
    return await create_category(session, name=payload.name, scope=payload.scope, description=payload.description)


@router.patch("/{category_id}", response_model=CostCategoryRead)
async def update_category_endpoint(
    category_id: UUID,
    payload: CostCategoryUpdate,
    session: AsyncSession = Depends(get_session),
    _admin: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> CostCategory:
    category = await session.get(CostCategory, category_id)
    if category is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Cost category not found")
    return await update_category(session, category, description=payload.description, active=payload.active)
