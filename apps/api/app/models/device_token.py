from datetime import datetime
from uuid import UUID, uuid4

from sqlmodel import Field, SQLModel

from app.core.clock import utcnow
from app.models.enums import DevicePlatform


class DeviceToken(SQLModel, table=True):
    """Token FCM của một thiết bị di động, dùng để gửi push notification.

    Một user có thể có nhiều token (nhiều thiết bị đăng nhập cùng lúc).
    `fcm_token` unique — đăng ký lại cùng token (refresh) sẽ upsert thay vì
    tạo dòng mới, kể cả khi token đó trước đó thuộc user khác (đổi máy/logout).
    """

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    user_id: UUID = Field(foreign_key="user.id", index=True)
    fcm_token: str = Field(unique=True, index=True)
    platform: DevicePlatform
    created_at: datetime = Field(default_factory=utcnow)
    last_seen_at: datetime = Field(default_factory=utcnow)
