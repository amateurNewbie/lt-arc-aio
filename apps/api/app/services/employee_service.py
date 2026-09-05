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


async def update_pay_override(
    session: AsyncSession,
    employee: Employee,
    *,
    pay_profile_id: UUID | None,
    daily_rate_override: int | None,
    allowance_overrides: list[dict] | None,
) -> Employee:
    """FR-16.5 — ghi đè đơn giá/phụ cấp riêng (thoả thuận cá nhân)."""
    if pay_profile_id is not None:
        employee.pay_profile_id = pay_profile_id
    if daily_rate_override is not None:
        employee.daily_rate_override = daily_rate_override
    if allowance_overrides is not None:
        employee.allowance_overrides = allowance_overrides
    session.add(employee)
    await session.commit()
    await session.refresh(employee)
    return employee
