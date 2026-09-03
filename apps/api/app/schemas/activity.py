from datetime import datetime
from uuid import UUID

from sqlmodel import SQLModel


class ActivityRead(SQLModel):
    id: UUID
    icon: str
    title: str
    project_id: UUID | None
    user_id: UUID
    created_at: datetime
