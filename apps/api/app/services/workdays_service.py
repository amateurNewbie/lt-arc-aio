import calendar
from uuid import UUID

from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.clock import utcnow
from app.models.user import User
from app.models.workdays import MonthlyWorkDays
from app.services.activity_service import log_activity


class WorkDaysLockedError(Exception):
    pass


def days_in_month(month: str) -> int:
    year, mon = (int(part) for part in month.split("-"))
    return calendar.monthrange(year, mon)[1]


async def list_month(session: AsyncSession, month: str) -> list[MonthlyWorkDays]:
    result = await session.exec(select(MonthlyWorkDays).where(MonthlyWorkDays.month == month))
    return list(result.all())


async def upsert_entries(
    session: AsyncSession,
    *,
    month: str,
    entries: list[dict],
    actor: User,
) -> list[MonthlyWorkDays]:
    """FR-15.1/15.2 — nhập/sửa số công; chặn nếu kỳ đã khoá (FR-15.3)."""
    existing = {w.employee_id: w for w in await list_month(session, month)}
    saved = []

    for entry in entries:
        employee_id: UUID = entry["employee_id"]
        actual_days: float = entry["actual_days"]
        current = existing.get(employee_id)

        if current is not None:
            if current.locked_at is not None:
                raise WorkDaysLockedError(f"Kỳ công tháng {month} đã khoá (lương đã trả)")
            current.actual_days = actual_days
            current.entered_by_id = actor.id
            current.updated_at = utcnow()
            session.add(current)
            saved.append(current)
        else:
            new_entry = MonthlyWorkDays(employee_id=employee_id, month=month, actual_days=actual_days, entered_by_id=actor.id)
            session.add(new_entry)
            saved.append(new_entry)

    await session.commit()
    for entry in saved:
        await session.refresh(entry)

    await log_activity(session, icon="clock", title=f"Nhập công tháng {month} cho {len(saved)} nhân viên", user_id=actor.id)
    return saved


async def lock_month(session: AsyncSession, month: str) -> None:
    """FR-15.3 — khoá sau khi Payroll tháng đó chuyển 'Đã trả'."""
    entries = await list_month(session, month)
    now = utcnow()
    for entry in entries:
        entry.locked_at = now
        session.add(entry)
    await session.commit()
