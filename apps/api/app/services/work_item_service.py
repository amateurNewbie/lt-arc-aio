from uuid import UUID

from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.models.enums import WorkItemStatus
from app.models.task import Task
from app.models.user import User
from app.models.work_item import WorkItem


async def create_work_item(
    session: AsyncSession,
    *,
    project_id: UUID,
    department_id: UUID,
    name: str,
    unit: str = "-",
    quantity: float = 1,
    unit_price: int = 0,
    actor: User | None = None,
    create_linked_task: bool = True,
) -> WorkItem:
    """Tạo hạng mục; tuỳ chọn tạo luôn 1 công việc liên kết ở tab Công việc."""
    work_item = WorkItem(
        project_id=project_id,
        department_id=department_id,
        name=name,
        unit=unit or "-",
        quantity=quantity,
        unit_price=unit_price,
        amount=round(quantity * unit_price),
    )
    session.add(work_item)
    await session.flush()

    if create_linked_task and actor is not None:
        session.add(
            Task(
                title=name,
                project_id=project_id,
                department_id=department_id,
                work_item_id=work_item.id,
            )
        )

    await session.commit()
    await session.refresh(work_item)
    return work_item


async def list_work_items(session: AsyncSession, project_id: UUID) -> list[WorkItem]:
    result = await session.exec(select(WorkItem).where(WorkItem.project_id == project_id))
    return list(result.all())


async def update_progress(session: AsyncSession, work_item: WorkItem, *, progress: int) -> WorkItem:
    """Cập nhật % hoàn thành hạng mục thủ công (admin); thường sync từ task."""
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
