from uuid import UUID

from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.models.department import Department
from app.models.user import User


async def create_department(session: AsyncSession, *, name: str, head_user_id: UUID | None) -> Department:
    """FR-13.1 — tạo bộ phận, gán Trưởng bộ phận phụ trách."""
    department = Department(name=name, head_user_id=head_user_id)
    session.add(department)
    await session.commit()
    await session.refresh(department)
    return department


async def update_department(
    session: AsyncSession,
    department: Department,
    *,
    name: str | None,
    head_user_id: UUID | None,
) -> Department:
    if name is not None:
        department.name = name
    if head_user_id is not None:
        department.head_user_id = head_user_id
    session.add(department)
    await session.commit()
    await session.refresh(department)
    return department


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


async def list_departments(session: AsyncSession) -> list[Department]:
    result = await session.exec(select(Department))
    return list(result.all())
