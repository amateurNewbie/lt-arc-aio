from uuid import UUID

from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.models.cost_category import CostCategory
from app.models.enums import CostCategoryScope


async def create_category(session: AsyncSession, *, name: str, scope: CostCategoryScope, description: str | None) -> CostCategory:
    """FR-7.1 — chỉ ADMIN/DIRECTOR khai báo (kiểm tra ở router)."""
    category = CostCategory(name=name, scope=scope, description=description)
    session.add(category)
    await session.commit()
    await session.refresh(category)
    return category


async def update_category(session: AsyncSession, category: CostCategory, *, description: str | None, active: bool | None) -> CostCategory:
    """FR-7.3 — không xoá vĩnh viễn; chỉ đổi active."""
    if description is not None:
        category.description = description
    if active is not None:
        category.active = active
    session.add(category)
    await session.commit()
    await session.refresh(category)
    return category


async def list_categories(session: AsyncSession, scope: CostCategoryScope | None = None) -> list[CostCategory]:
    query = select(CostCategory)
    if scope is not None:
        query = query.where(CostCategory.scope == scope)
    result = await session.exec(query)
    return list(result.all())
