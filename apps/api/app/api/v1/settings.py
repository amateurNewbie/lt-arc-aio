from fastapi import APIRouter, Depends
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.deps import get_session, require_roles
from app.core.permissions import Role
from app.models.company_settings import CompanySettings
from app.models.user import User
from app.schemas.company_settings import CompanySettingsRead, CompanySettingsUpdate, SecurityStatusItem
from app.services.settings_service import get_company_settings, security_status, update_company_settings

router = APIRouter(prefix="/api/settings", tags=["settings"])


@router.get("", response_model=CompanySettingsRead)
async def get_settings_endpoint(session: AsyncSession = Depends(get_session)) -> CompanySettings:
    """FR-20.1 — thông tin chung của studio."""
    return await get_company_settings(session)


@router.patch("", response_model=CompanySettingsRead)
async def update_settings_endpoint(
    payload: CompanySettingsUpdate,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> CompanySettings:
    """FR-20.2 — chỉ ADMIN/Giám đốc sửa."""
    return await update_company_settings(session, payload.model_dump(exclude_unset=True))


@router.get("/security-status", response_model=list[SecurityStatusItem])
async def security_status_endpoint(
    _user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> list[dict]:
    """FR-20.4 — minh bạch hoá các biện pháp bảo mật đang áp dụng."""
    return security_status()
