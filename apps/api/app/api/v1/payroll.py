from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.deps import get_current_user, get_session, require_roles
from app.core.permissions import Role
from app.models.payroll import PayrollRecord
from app.models.user import User
from app.schemas.payroll import PayrollPayRequest, PayrollRecordRead, PayrollRunRequest
from app.services.payroll_service import PayrollAlreadyPaidError, get_own_record, list_month, mark_paid, run_payroll

router = APIRouter(prefix="/api/payroll", tags=["payroll"])


@router.get("", response_model=list[PayrollRecordRead])
async def list_payroll_endpoint(
    month: str,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
) -> list[PayrollRecord]:
    """FR-16.2/16.4 — Nhân viên chỉ xem phiếu lương của chính mình."""
    if user.role == Role.EMPLOYEE:
        record = await get_own_record(session, user, month)
        return [record] if record else []
    return await list_month(session, month)


@router.post("/run", response_model=list[PayrollRecordRead])
async def run_payroll_endpoint(
    payload: PayrollRunRequest,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> list[PayrollRecord]:
    """FR-16.1 — tính lương tự động từ số công đã nhập."""
    return await run_payroll(session, payload.month)


@router.post("/pay", response_model=list[PayrollRecordRead])
async def pay_payroll_endpoint(
    month: str,
    payload: PayrollPayRequest,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(require_roles(Role.ADMIN)),
) -> list[PayrollRecord]:
    """FR-16.3 — chỉ ADMIN đánh dấu đã trả (từng người hoặc theo lô)."""
    try:
        return await mark_paid(session, month=month, fund_account_id=payload.fund_account_id, employee_ids=payload.employee_ids, actor=user)
    except PayrollAlreadyPaidError as exc:
        raise HTTPException(status.HTTP_409_CONFLICT, str(exc)) from exc


@router.patch("/{record_id}/pay", response_model=PayrollRecordRead)
async def pay_single_payroll_endpoint(
    record_id: UUID,
    payload: PayrollPayRequest,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(require_roles(Role.ADMIN)),
) -> PayrollRecord:
    """FR-16.3 — đánh dấu đã trả cho một nhân viên."""
    record = await session.get(PayrollRecord, record_id)
    if record is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Payroll record not found")
    try:
        paid = await mark_paid(session, month=record.month, fund_account_id=payload.fund_account_id, employee_ids=[record.employee_id], actor=user)
    except PayrollAlreadyPaidError as exc:
        raise HTTPException(status.HTTP_409_CONFLICT, str(exc)) from exc
    return paid[0]
