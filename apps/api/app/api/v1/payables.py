from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.deps import get_session, require_perm, require_roles
from app.core.permissions import PermissionGroup, Role
from app.models.payable import Payable
from app.models.project import ProjectDepartmentHead
from app.models.user import User
from app.schemas.payable import PayableCreate, PayableRead, PayableSettleRequest
from app.services.payable_service import PayableOverpaidError, create_payable, list_payables, settle

router = APIRouter(prefix="/api/payables", tags=["payables"])


@router.get("", response_model=list[PayableRead])
async def list_payables_endpoint(
    session: AsyncSession = Depends(get_session),
    user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR, Role.DEPARTMENT_HEAD)),
) -> list[Payable]:
    """FR-10.2/10.4; RBAC §2.6 — Trưởng bộ phận chỉ xem dự án mình phụ trách."""
    payables = await list_payables(session)
    if user.role == Role.DEPARTMENT_HEAD:
        result = await session.exec(select(ProjectDepartmentHead.project_id).where(ProjectDepartmentHead.user_id == user.id))
        own_project_ids = set(result.all())
        payables = [p for p in payables if p.project_id in own_project_ids]
    return payables


@router.post("", response_model=PayableRead, status_code=status.HTTP_201_CREATED)
async def create_payable_endpoint(
    payload: PayableCreate,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(require_perm(PermissionGroup.DEBTS)),
) -> Payable:
    return await create_payable(
        session,
        project_id=payload.project_id,
        vendor_name=payload.vendor_name,
        cost_category_id=payload.cost_category_id,
        total_amount=payload.total_amount,
        due_date=payload.due_date,
    )


@router.post("/{payable_id}/settle", response_model=PayableRead)
async def settle_payable_endpoint(
    payable_id: UUID,
    payload: PayableSettleRequest,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(require_perm(PermissionGroup.DEBTS)),
) -> Payable:
    """FR-10.3 — tạo bút toán Sổ quỹ (FR-12)."""
    payable = await session.get(Payable, payable_id)
    if payable is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Payable not found")
    try:
        return await settle(
            session, payable, amount=payload.amount, fund_account_id=payload.fund_account_id, actor=user, on=payload.date
        )
    except PayableOverpaidError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc)) from exc
