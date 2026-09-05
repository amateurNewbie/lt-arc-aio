from uuid import UUID

from sqlmodel import SQLModel

from app.models.enums import CostCategoryScope


class CostCategoryCreate(SQLModel):
    name: str
    scope: CostCategoryScope
    description: str | None = None


class CostCategoryUpdate(SQLModel):
    description: str | None = None
    active: bool | None = None
    """FR-7.3 — không xoá vĩnh viễn, chỉ chuyển 'Ngừng dùng' (active=False)."""


class CostCategoryRead(SQLModel):
    id: UUID
    name: str
    scope: CostCategoryScope
    description: str | None
    active: bool
