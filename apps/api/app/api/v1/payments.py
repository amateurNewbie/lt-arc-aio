from uuid import UUID

from fastapi import APIRouter, Depends
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.deps import get_current_user, get_session
from app.models.payment import Payment
from app.models.user import User
from app.schemas.payment import PaymentRead

router = APIRouter(prefix="/api/payments", tags=["payments"])


@router.get("", response_model=list[PaymentRead])
async def list_payments_endpoint(
    project_id: UUID | None = None,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(get_current_user),
) -> list[Payment]:
    """FR-6.4 — sổ Thu & Chi (phần Thu) — ghi nhận qua collect milestone (FR-9.3)."""
    query = select(Payment)
    if project_id is not None:
        query = query.where(Payment.project_id == project_id)
    result = await session.exec(query.order_by(Payment.date.desc()))
    return list(result.all())
