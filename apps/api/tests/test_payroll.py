from httpx import AsyncClient
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.permissions import Role
from app.core.security import create_access_token
from app.models.enums import FundType, PayrollStatus
from app.services.auth_service import create_user
from app.services.employee_service import create_employee, update_pay_override
from app.services.fund_service import create_fund
from app.services.pay_profile_service import create_profile, effective_pay
from app.services.payroll_service import PayrollAlreadyPaidError, mark_paid, run_payroll
from app.services.workdays_service import WorkDaysLockedError, upsert_entries


def _auth_headers(user) -> dict:
    return {"Authorization": f"Bearer {create_access_token(user.id)}"}


async def test_employee_override_takes_precedence_over_pay_profile(session: AsyncSession) -> None:
    """FR-16.5 — nhân viên kế thừa chức danh, nhưng ghi đè riêng của nhân viên thắng."""
    director = await create_user(session, email="pr1@ltarc.vn", password="x", role=Role.DIRECTOR)
    profile = await create_profile(
        session, role_title="Thợ điện Test", daily_rate=500_000, allowances=[{"name": "Ăn trưa", "amount": 50_000}]
    )
    employee_user = await create_user(session, email="emppr1@ltarc.vn", password="x", role=Role.EMPLOYEE)
    employee = await create_employee(session, user_id=employee_user.id, phone=None, hire_date=None, pay_profile_id=profile.id)

    daily_rate, allowances = await effective_pay(employee, profile)
    assert daily_rate == 500_000
    assert allowances == [{"name": "Ăn trưa", "amount": 50_000}]

    employee = await update_pay_override(
        session, employee, pay_profile_id=None, daily_rate_override=650_000, allowance_overrides=[{"name": "Xăng xe", "amount": 30_000}]
    )
    daily_rate, allowances = await effective_pay(employee, profile)
    assert daily_rate == 650_000  # override thắng, không dùng giá của profile
    assert allowances == [{"name": "Xăng xe", "amount": 30_000}]


async def test_payroll_run_computes_net_pay_and_pay_marks_paid_atomically(session: AsyncSession) -> None:
    """FR-16.1/16.2/16.3 — tính lương đúng công thức; trả lương tạo bút toán quỹ + khoá số công."""
    director = await create_user(session, email="pr2@ltarc.vn", password="x", role=Role.DIRECTOR)
    profile = await create_profile(session, role_title="Kỹ sư Test", daily_rate=500_000, allowances=[{"name": "Ăn trưa", "amount": 50_000}])
    employee_user = await create_user(session, email="emppr2@ltarc.vn", password="x", role=Role.EMPLOYEE)
    employee = await create_employee(session, user_id=employee_user.id, phone=None, hire_date=None, pay_profile_id=profile.id)
    fund = await create_fund(session, name="Quỹ lương Test", type_=FundType.CASH, balance=100_000_000)

    await upsert_entries(session, month="2026-07", entries=[{"employee_id": employee.id, "actual_days": 22}], actor=director)

    records = await run_payroll(session, "2026-07")
    assert len(records) == 1
    record = records[0]
    assert record.day_wage == 500_000 * 22
    assert record.net_pay == 500_000 * 22 + 50_000
    assert record.status == PayrollStatus.UNPAID

    paid = await mark_paid(session, month="2026-07", fund_account_id=fund.id, employee_ids=None, actor=director)
    assert paid[0].status == PayrollStatus.PAID

    await session.refresh(fund)
    assert fund.balance == 100_000_000 - record.net_pay

    try:
        await mark_paid(session, month="2026-07", fund_account_id=fund.id, employee_ids=None, actor=director)
        assert False, "expected PayrollAlreadyPaidError — không còn bản UNPAID"
    except PayrollAlreadyPaidError:
        pass

    # FR-16.6 — kỳ đã chốt giữ nguyên snapshot dù chạy lại run_payroll.
    reran = await run_payroll(session, "2026-07")
    assert reran == []


async def test_workdays_locked_after_payroll_paid(session: AsyncSession) -> None:
    """FR-15.3 — số công bị khoá sau khi lương tháng đó đã trả."""
    director = await create_user(session, email="pr3@ltarc.vn", password="x", role=Role.DIRECTOR)
    profile = await create_profile(session, role_title="Nhân viên Test", daily_rate=400_000, allowances=[])
    employee_user = await create_user(session, email="emppr3@ltarc.vn", password="x", role=Role.EMPLOYEE)
    employee = await create_employee(session, user_id=employee_user.id, phone=None, hire_date=None, pay_profile_id=profile.id)
    fund = await create_fund(session, name="Quỹ lương Test 2", type_=FundType.CASH, balance=50_000_000)

    await upsert_entries(session, month="2026-08", entries=[{"employee_id": employee.id, "actual_days": 20}], actor=director)
    await run_payroll(session, "2026-08")
    await mark_paid(session, month="2026-08", fund_account_id=fund.id, employee_ids=None, actor=director)

    try:
        await upsert_entries(session, month="2026-08", entries=[{"employee_id": employee.id, "actual_days": 21}], actor=director)
        assert False, "expected WorkDaysLockedError — kỳ đã khoá"
    except WorkDaysLockedError:
        pass


async def test_role_preview_is_read_only(client: AsyncClient, session: AsyncSession) -> None:
    """FR-1.6 — Admin xem thử vai trò khác, chỉ đọc; các hành động ghi bị chặn 403."""
    admin = await create_user(session, email="pr4@ltarc.vn", password="x", role=Role.ADMIN)
    employee = await create_user(session, email="emppr4@ltarc.vn", password="x", role=Role.EMPLOYEE)

    resp = await client.post("/api/auth/preview-role", headers=_auth_headers(admin), json={"role": "EMPLOYEE"})
    assert resp.status_code == 200
    preview_token = resp.json()["access_token"]
    preview_headers = {"Authorization": f"Bearer {preview_token}"}

    me = await client.get("/api/auth/me", headers=preview_headers)
    assert me.status_code == 200
    assert me.json()["role"] == "EMPLOYEE"

    write_resp = await client.patch("/api/settings", headers=preview_headers, json={"name": "Hack"})
    assert write_resp.status_code == 403
    assert "read-only" in write_resp.json()["detail"].lower() or "read-only" in write_resp.text.lower()

    forbidden = await client.post("/api/auth/preview-role", headers=_auth_headers(employee), json={"role": "ADMIN"})
    assert forbidden.status_code == 403
