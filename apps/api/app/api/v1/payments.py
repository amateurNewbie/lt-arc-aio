from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.deps import get_current_user, get_session, require_roles
from app.core.permissions import Role
from app.models.payment import Payment
from app.models.user import User
from app.schemas.payment import PaymentCreate, PaymentRead
from app.services.payment_service import MilestoneOverpaidError, create_project_payment

router = APIRouter(prefix="/api/payments", tags=["payments"])


@router.get("", response_model=list[PaymentRead])
async def list_payments_endpoint(
    project_id: UUID | None = None,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(get_current_user),
) -> list[Payment]:
    query = select(Payment)
    if project_id is not None:
        query = query.where(Payment.project_id == project_id)
    result = await session.exec(query.order_by(Payment.date.desc()))
    return list(result.all())


@router.post("", response_model=PaymentRead, status_code=status.HTTP_201_CREATED)
async def create_payment_endpoint(
    payload: PaymentCreate,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR, Role.DEPARTMENT_HEAD)),
) -> Payment:
    """Thu dự án — tự do (note) hoặc gắn milestone."""
    try:
        return await create_project_payment(
            session,
            project_id=payload.project_id,
            amount=payload.amount,
            fund_account_id=payload.fund_account_id,
            actor=user,
            on=payload.date,
            note=payload.note,
            contract_milestone_id=payload.contract_milestone_id,
        )
    except MilestoneOverpaidError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc)) from exc
