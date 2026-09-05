from datetime import datetime
from uuid import UUID

from sqlmodel import SQLModel


class FileAssetRead(SQLModel):
    id: UUID
    project_id: UUID
    name: str
    type: str
    size_bytes: int
    uploaded_by_id: UUID
    created_at: datetime
