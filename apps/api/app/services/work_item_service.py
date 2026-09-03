from uuid import UUID

from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.models.work_item import WorkItem


async def create_work_item(
    session: AsyncSession,
    *,
    project_id: UUID,
    department_id: UUID,
    name: str,
    unit: str,
    quantity: float,
    unit_price: int,
) -> WorkItem:
    """FR-5.5 — thành tiền tự tính từ khối lượng × đơn giá."""
    work_item = WorkItem(
        project_id=project_id,
        department_id=department_id,
        name=name,
        unit=unit,
        quantity=quantity,
        unit_price=unit_price,
        amount=round(quantity * unit_price),
    )
    session.add(work_item)
    await session.commit()
    await session.refresh(work_item)
    return work_item


async def list_work_items(session: AsyncSession, project_id: UUID) -> list[WorkItem]:
    result = await session.exec(select(WorkItem).where(WorkItem.project_id == project_id))
    return list(result.all())
