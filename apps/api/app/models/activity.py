from datetime import datetime
from uuid import UUID, uuid4

from sqlmodel import Field, SQLModel

from app.core.clock import utcnow


class Activity(SQLModel, table=True):
    """FR-18 — nhật ký hoạt động, chỉ hệ thống ghi tự động (không có endpoint tạo thủ công)."""

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    icon: str
    title: str
    project_id: UUID | None = Field(default=None, foreign_key="project.id", index=True)
    user_id: UUID = Field(foreign_key="user.id", index=True)
    created_at: datetime = Field(default_factory=utcnow, index=True)
