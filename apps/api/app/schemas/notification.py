from datetime import datetime
from uuid import UUID

from sqlmodel import SQLModel


class NotificationRead(SQLModel):
    id: UUID
    title: str
    message: str
    read: bool
    created_at: datetime
