from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.models.employee import Employee
from app.models.pay_profile import PayProfile


async def create_profile(session: AsyncSession, *, role_title: str, daily_rate: int, allowances: list[dict]) -> PayProfile:
    """FR-16.5 — đơn giá lương ngày + bộ phụ cấp mặc định theo chức danh."""
    profile = PayProfile(role_title=role_title, daily_rate=daily_rate, allowances=allowances)
    session.add(profile)
    await session.commit()
    await session.refresh(profile)
    return profile


async def update_profile(
    session: AsyncSession,
    profile: PayProfile,
    *,
    daily_rate: int | None,
    allowances: list[dict] | None,
    active: bool | None,
) -> PayProfile:
    """FR-16.6 — thay đổi chỉ áp dụng cho kỳ lương chưa chốt (service payroll tự snapshot)."""
    if daily_rate is not None:
        profile.daily_rate = daily_rate
    if allowances is not None:
        profile.allowances = allowances
    if active is not None:
        profile.active = active
    session.add(profile)
    await session.commit()
    await session.refresh(profile)
    return profile


async def list_profiles(session: AsyncSession) -> list[PayProfile]:
    result = await session.exec(select(PayProfile))
    return list(result.all())


async def effective_pay(employee: Employee, profile: PayProfile | None) -> tuple[int, list[dict]]:
    """FR-16.5 — nhân viên kế thừa chức danh, có thể ghi đè riêng."""
    daily_rate = employee.daily_rate_override if employee.daily_rate_override is not None else (profile.daily_rate if profile else 0)
    allowances = employee.allowance_overrides if employee.allowance_overrides is not None else (profile.allowances if profile else [])
    return daily_rate, allowances
