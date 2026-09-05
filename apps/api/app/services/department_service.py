from uuid import UUID

from sqlmodel import func, select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.models.department import Department
from app.models.enums import TaskStatus
from app.models.task import Task
from app.models.user import User
from app.schemas.department import DepartmentRead


async def create_department(session: AsyncSession, *, name: str, head_user_id: UUID | None) -> DepartmentRead:
    """FR-13.1 — tạo bộ phận, gán Trưởng bộ phận phụ trách."""
    department = Department(name=name, head_user_id=head_user_id)
    session.add(department)
    await session.commit()
    await session.refresh(department)
    return await _with_stats(session, department)


async def update_department(
    session: AsyncSession,
    department: Department,
    *,
    name: str | None,
    head_user_id: UUID | None,
) -> DepartmentRead:
    if name is not None:
        department.name = name
    if head_user_id is not None:
        department.head_user_id = head_user_id
    session.add(department)
    await session.commit()
    await session.refresh(department)
    return await _with_stats(session, department)


async def assign_employee_to_department(session: AsyncSession, user_id: UUID, department_id: UUID) -> User:
    """FR-13.2 — mỗi nhân viên thuộc đúng một bộ phận tại một thời điểm."""
    user = await session.get(User, user_id)
    if user is None:
        raise ValueError("User not found")
    user.department_id = department_id
    session.add(user)
    await session.commit()
    await session.refresh(user)
    return user


async def _with_stats(session: AsyncSession, department: Department) -> DepartmentRead:
    """FR-13 — kèm thống kê thật (số nhân viên/việc đang làm/tiến độ trung bình),
    không dùng số liệu tĩnh."""
    employee_count = (
        await session.exec(select(func.count()).select_from(User).where(User.department_id == department.id))
    ).one()
    active_task_count = (
        await session.exec(
            select(func.count()).select_from(Task).where(Task.department_id == department.id, Task.status != TaskStatus.DONE)
        )
    ).one()
    avg_progress = (
        await session.exec(select(func.avg(Task.progress)).select_from(Task).where(Task.department_id == department.id))
    ).one()
    return DepartmentRead(
        id=department.id,
        name=department.name,
        head_user_id=department.head_user_id,
        employee_count=employee_count,
        active_task_count=active_task_count,
        avg_task_progress=round(float(avg_progress), 1) if avg_progress is not None else 0.0,
    )


async def list_departments(session: AsyncSession) -> list[DepartmentRead]:
    departments = (await session.exec(select(Department))).all()
    return [await _with_stats(session, department) for department in departments]
