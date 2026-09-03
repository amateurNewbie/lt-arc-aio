from fastapi import APIRouter, Depends
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.deps import get_current_user, get_session
from app.models.activity import Activity
from app.models.user import User
from app.schemas.activity import ActivityRead
from app.services.activity_service import list_recent_activities

router = APIRouter(prefix="/api/activities", tags=["activities"])


@router.get("", response_model=list[ActivityRead])
async def list_activities_endpoint(
    limit: int = 50,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
) -> list[Activity]:
    """FR-18.2 — phạm vi tự động thu hẹp theo vai trò (xem activity_service)."""
    return await list_recent_activities(session, user, limit=limit)
