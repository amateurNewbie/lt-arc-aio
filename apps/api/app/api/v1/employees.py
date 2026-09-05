from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.deps import get_session, require_roles
from app.core.permissions import Role
from app.models.employee import Employee
from app.models.user import User
from app.schemas.employee import EmployeeCreate, EmployeeRead
from app.schemas.pay_profile import EmployeePayOverrideUpdate
from app.services.employee_service import create_employee, list_employees, update_pay_override

router = APIRouter(prefix="/api/employees", tags=["employees"])


@router.get("", response_model=list[EmployeeRead])
async def list_employees_endpoint(
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR, Role.DEPARTMENT_HEAD)),
) -> list[Employee]:
    """FR-14.2 — danh sách nhân sự toàn công ty (Trưởng bộ phận chỉ xem, không sửa)."""
    return await list_employees(session)


@router.post("", response_model=EmployeeRead, status_code=status.HTTP_201_CREATED)
async def create_employee_endpoint(
    payload: EmployeeCreate,
    session: AsyncSession = Depends(get_session),
    _admin: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> Employee:
    """FR-14.3 — chỉ Admin/Giám đốc thêm nhân viên mới."""
    return await create_employee(
        session,
        user_id=payload.user_id,
        phone=payload.phone,
        hire_date=payload.hire_date,
        pay_profile_id=payload.pay_profile_id,
    )


@router.patch("/{employee_id}/pay", response_model=EmployeeRead)
async def update_employee_pay_endpoint(
    employee_id: UUID,
    payload: EmployeePayOverrideUpdate,
    session: AsyncSession = Depends(get_session),
    _admin: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> Employee:
    """FR-16.5 — ghi đè đơn giá ngày/phụ cấp riêng cho một nhân viên."""
    employee = await session.get(Employee, employee_id)
    if employee is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Employee not found")
    allowance_overrides = [a.model_dump() for a in payload.allowance_overrides] if payload.allowance_overrides is not None else None
    return await update_pay_override(
        session,
        employee,
        pay_profile_id=payload.pay_profile_id,
        daily_rate_override=payload.daily_rate_override,
        allowance_overrides=allowance_overrides,
    )
