from uuid import UUID

from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.models.employee import Employee
from app.models.enums import PayrollStatus
from app.models.fund import CashLedgerEntry, FundAccount
from app.models.pay_profile import PayProfile
from app.models.payroll import PayrollRecord
from app.models.user import User
from app.models.workdays import MonthlyWorkDays
from app.services.activity_service import log_activity
from app.services.pay_profile_service import effective_pay
from app.services.workdays_service import lock_month


class PayrollAlreadyPaidError(Exception):
    pass


def _compute_net_pay(daily_rate: int, actual_days: float, allowances: list[dict]) -> tuple[int, int]:
    """FR-16.1 — Thực lãnh = Số công thực tế × Đơn giá lương ngày + Phụ cấp."""
    day_wage = round(daily_rate * actual_days)
    allowance_total = sum(a.get("amount", 0) for a in allowances)
    return day_wage, day_wage + allowance_total


async def run_payroll(session: AsyncSession, month: str) -> list[PayrollRecord]:
    """FR-16.1 — tính lương cho mọi nhân viên đã có số công tháng này.

    Ghi đè (chưa chốt) nếu record của tháng đã tồn tại nhưng còn UNPAID —
    không đụng tới record đã PAID (invariant FR-16.6).
    """
    workdays_result = await session.exec(select(MonthlyWorkDays).where(MonthlyWorkDays.month == month))
    workdays_by_employee = {w.employee_id: w for w in workdays_result.all()}

    existing_result = await session.exec(select(PayrollRecord).where(PayrollRecord.month == month))
    existing_by_employee = {r.employee_id: r for r in existing_result.all()}

    records = []
    for employee_id, workdays in workdays_by_employee.items():
        existing = existing_by_employee.get(employee_id)
        if existing is not None and existing.status == PayrollStatus.PAID:
            continue  # FR-16.6 — kỳ đã chốt giữ nguyên snapshot

        employee = await session.get(Employee, employee_id)
        profile = await session.get(PayProfile, employee.pay_profile_id) if employee.pay_profile_id else None
        daily_rate, allowances = await effective_pay(employee, profile)
        day_wage, net_pay = _compute_net_pay(daily_rate, workdays.actual_days, allowances)

        if existing is not None:
            existing.daily_rate = daily_rate
            existing.actual_days = workdays.actual_days
            existing.day_wage = day_wage
            existing.allowances = allowances
            existing.net_pay = net_pay
            session.add(existing)
            records.append(existing)
        else:
            record = PayrollRecord(
                employee_id=employee_id,
                month=month,
                daily_rate=daily_rate,
                actual_days=workdays.actual_days,
                day_wage=day_wage,
                allowances=allowances,
                net_pay=net_pay,
            )
            session.add(record)
            records.append(record)

    await session.commit()
    for record in records:
        await session.refresh(record)
    return records


async def mark_paid(
    session: AsyncSession,
    *,
    month: str,
    fund_account_id: UUID,
    employee_ids: list[UUID] | None,
    actor: User,
) -> list[PayrollRecord]:
    """FR-16.3 — đánh dấu đã trả (từng người hoặc theo lô); tạo bút toán Sổ quỹ
    (FR-12.2) + khoá số công tháng đó (FR-15.3)."""
    query = select(PayrollRecord).where(PayrollRecord.month == month, PayrollRecord.status == PayrollStatus.UNPAID)
    if employee_ids is not None:
        query = query.where(PayrollRecord.employee_id.in_(employee_ids))
    result = await session.exec(query)
    records = result.all()
    if not records:
        raise PayrollAlreadyPaidError("Không có bản lương UNPAID nào để trả")

    fund = await session.get(FundAccount, fund_account_id)
    if fund is None:
        raise ValueError("Fund account not found")

    total = 0
    for record in records:
        record.status = PayrollStatus.PAID
        session.add(record)
        total += record.net_pay

    session.add(
        CashLedgerEntry(
            fund_account_id=fund_account_id,
            description=f"Chi lương tháng {month} ({len(records)} nhân viên)",
            inflow=0,
            outflow=total,
            source_type="payroll",
            source_id=records[0].id,
            recorded_by_id=actor.id,
        )
    )
    fund.balance -= total
    session.add(fund)

    await session.commit()
    for record in records:
        await session.refresh(record)

    await lock_month(session, month)
    await log_activity(session, icon="wallet", title=f"Chốt & trả lương tháng {month} ({len(records)} nhân viên)", user_id=actor.id)
    return records


async def list_month(session: AsyncSession, month: str) -> list[PayrollRecord]:
    result = await session.exec(select(PayrollRecord).where(PayrollRecord.month == month))
    return list(result.all())


async def get_own_record(session: AsyncSession, user: User, month: str) -> PayrollRecord | None:
    """FR-16.4 — nhân viên chỉ xem phiếu lương của chính mình."""
    employee_result = await session.exec(select(Employee).where(Employee.user_id == user.id))
    employee = employee_result.first()
    if employee is None:
        return None
    result = await session.exec(select(PayrollRecord).where(PayrollRecord.employee_id == employee.id, PayrollRecord.month == month))
    return result.first()
