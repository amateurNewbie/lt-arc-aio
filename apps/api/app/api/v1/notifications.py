from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.deps import get_current_user, get_session
from app.models.notification import Notification
from app.models.user import User
from app.schemas.notification import NotificationRead
from app.services.notification_service import NotificationForbiddenError, list_for_user, mark_read

router = APIRouter(prefix="/api/notifications", tags=["notifications"])


@router.get("", response_model=list[NotificationRead])
async def list_notifications_endpoint(
    unread_only: bool = False,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
) -> list[Notification]:
    """FR-19.1 — danh sách thông báo riêng cho từng người dùng."""
    return await list_for_user(session, user, unread_only=unread_only)


@router.patch("/{notification_id}/read", response_model=NotificationRead)
async def mark_notification_read_endpoint(
    notification_id: UUID,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
) -> Notification:
    """FR-19.3 — người dùng chỉ đánh dấu được thông báo của chính mình."""
    notification = await session.get(Notification, notification_id)
    if notification is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Notification not found")
    try:
        return await mark_read(session, notification, user)
    except NotificationForbiddenError as exc:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your notification") from exc
