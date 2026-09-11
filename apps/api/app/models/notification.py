from datetime import datetime
from uuid import UUID, uuid4

from sqlmodel import Field, SQLModel

from app.core.clock import utcnow


class Notification(SQLModel, table=True):
    """FR-19 — thông báo riêng cho từng người dùng."""

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    user_id: UUID = Field(foreign_key="user.id", index=True)
    title: str
    message: str
    read: bool = Field(default=False, index=True)
    created_at: datetime = Field(default_factory=utcnow, index=True)

    # Lưu trữ dạng chuỗi tự do (xem `NotificationKind`), không phải cột Enum,
    # để mở rộng thêm loại thông báo sau này không cần migration ALTER TYPE.
    kind: str | None = Field(default=None, index=True)
    entity_type: str | None = Field(default=None)
    entity_id: UUID | None = Field(default=None)
