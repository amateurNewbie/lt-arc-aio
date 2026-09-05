from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.deps import get_session, require_roles
from app.core.permissions import Role
from app.models.pay_profile import PayProfile
from app.models.user import User
from app.schemas.pay_profile import PayProfileCreate, PayProfileRead, PayProfileUpdate
from app.services.pay_profile_service import create_profile, list_profiles, update_profile

router = APIRouter(prefix="/api/pay-profiles", tags=["pay-profiles"])


@router.get("", response_model=list[PayProfileRead])
async def list_pay_profiles_endpoint(
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> list[PayProfile]:
    return await list_profiles(session)


@router.post("", response_model=PayProfileRead, status_code=status.HTTP_201_CREATED)
async def create_pay_profile_endpoint(
    payload: PayProfileCreate,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> PayProfile:
    """FR-16.5 — chỉ Admin/Giám đốc cấu hình lương theo chức danh."""
    return await create_profile(
        session,
        role_title=payload.role_title,
        daily_rate=payload.daily_rate,
        allowances=[a.model_dump() for a in payload.allowances],
    )


@router.patch("/{profile_id}", response_model=PayProfileRead)
async def update_pay_profile_endpoint(
    profile_id: UUID,
    payload: PayProfileUpdate,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> PayProfile:
    profile = await session.get(PayProfile, profile_id)
    if profile is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Pay profile not found")
    allowances = [a.model_dump() for a in payload.allowances] if payload.allowances is not None else None
    return await update_profile(session, profile, daily_rate=payload.daily_rate, allowances=allowances, active=payload.active)
