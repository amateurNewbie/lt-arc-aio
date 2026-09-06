from uuid import UUID, uuid4

from sqlmodel import Field, SQLModel


class ProjectStageTemplate(SQLModel, table=True):
    """Mẫu giai đoạn tiến độ dự án — cấu hình ở Cài đặt, dùng khi tạo DA."""

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    key: str = Field(unique=True, index=True)
    name: str
    sort_order: int = Field(default=0)
    active: bool = Field(default=True, index=True)
