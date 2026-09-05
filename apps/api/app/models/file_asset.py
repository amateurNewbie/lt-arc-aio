from datetime import datetime
from uuid import UUID, uuid4

from sqlmodel import Field, SQLModel

from app.core.clock import utcnow


class FileAsset(SQLModel, table=True):
    """FR-17 — tệp đính kèm, chỉ áp dụng theo dự án."""

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    project_id: UUID = Field(foreign_key="project.id", index=True)
    name: str
    type: str  # content-type / mime
    size_bytes: int
    storage_key: str  # đường dẫn tương đối dưới FILE_ROOT
    uploaded_by_id: UUID = Field(foreign_key="user.id")
    created_at: datetime = Field(default_factory=utcnow)
