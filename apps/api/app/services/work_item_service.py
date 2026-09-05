from uuid import UUID

from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.models.enums import WorkItemStatus
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


async def update_progress(session: AsyncSession, work_item: WorkItem, *, progress: int) -> WorkItem:
    """FR-5.5 — cập nhật % hoàn thành hạng mục; 100% tự chuyển DONE, dưới 100%
    tự chuyển IN_PROGRESS nếu đang NOT_STARTED/DONE."""
    progress = max(0, min(100, progress))
    work_item.progress = progress
    if progress == 100:
        work_item.status = WorkItemStatus.DONE
    elif progress > 0:
        work_item.status = WorkItemStatus.IN_PROGRESS
    else:
        work_item.status = WorkItemStatus.NOT_STARTED
    session.add(work_item)
    await session.commit()
    await session.refresh(work_item)
    return work_item
