from uuid import UUID, uuid4

from sqlmodel import Field, SQLModel

from app.models.enums import CostCategoryScope


class CostCategory(SQLModel, table=True):
    """FR-7 — danh mục hạng mục chi phí dùng chung toàn hệ thống."""

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    name: str
    scope: CostCategoryScope = Field(index=True)
    description: str | None = Field(default=None)
    active: bool = Field(default=True)
