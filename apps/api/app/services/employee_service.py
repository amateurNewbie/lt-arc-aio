from datetime import date
from uuid import UUID

from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.models.employee import Employee


async def create_employee(
    session: AsyncSession,
    *,
    user_id: UUID,
    phone: str | None,
    hire_date: date | None,
    pay_profile_id: UUID | None,
) -> Employee:
    """FR-14.1/14.3 — hồ sơ nhân viên cơ bản, gán tài khoản đăng nhập đã có sẵn."""
    employee = Employee(user_id=user_id, phone=phone, hire_date=hire_date, pay_profile_id=pay_profile_id)
    session.add(employee)
    await session.commit()
    await session.refresh(employee)
    return employee


async def list_employees(session: AsyncSession) -> list[Employee]:
    result = await session.exec(select(Employee))
    return list(result.all())
