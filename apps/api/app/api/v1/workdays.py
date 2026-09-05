from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.deps import get_current_user, get_session, require_perm
from app.core.permissions import PermissionGroup, Role
from app.models.employee import Employee
from app.models.user import User
from app.models.workdays import MonthlyWorkDays
from app.schemas.workdays import MonthlyWorkDaysRead, WorkDaysUpsertRequest
from app.services.workdays_service import WorkDaysLockedError, days_in_month, list_month, upsert_entries

router = APIRouter(prefix="/api/workdays", tags=["workdays"])


def _to_read(entry: MonthlyWorkDays) -> MonthlyWorkDaysRead:
    return MonthlyWorkDaysRead(
        **entry.model_dump(),
        is_over_days_in_month=entry.actual_days > days_in_month(entry.month),
    )


@router.get("/{month}", response_model=list[MonthlyWorkDaysRead])
async def get_month_endpoint(
    month: str,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
) -> list[MonthlyWorkDaysRead]:
    """FR-15; RBAC §2.6 — Nhân viên chỉ xem số công của bản thân."""
    entries = await list_month(session, month)

    if user.role == Role.EMPLOYEE:
        result = await session.exec(select(Employee).where(Employee.user_id == user.id))
        employee = result.first()
        entries = [e for e in entries if employee is not None and e.employee_id == employee.id]

    return [_to_read(e) for e in entries]


@router.put("/{month}", response_model=list[MonthlyWorkDaysRead])
async def upsert_month_endpoint(
    month: str,
    payload: WorkDaysUpsertRequest,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(require_perm(PermissionGroup.WORKDAYS_ENTRY)),
) -> list[MonthlyWorkDaysRead]:
    """FR-15.1/15.2 — nhập/sửa số công cuối tháng."""
    try:
        saved = await upsert_entries(session, month=month, entries=[e.model_dump() for e in payload.entries], actor=user)
    except WorkDaysLockedError as exc:
        raise HTTPException(status.HTTP_409_CONFLICT, str(exc)) from exc
    return [_to_read(e) for e in saved]
