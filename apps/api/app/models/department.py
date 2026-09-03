from uuid import UUID, uuid4

from sqlmodel import Field, SQLModel


class Department(SQLModel, table=True):
    """FR-13 — bộ phận trong studio, có một Trưởng bộ phận phụ trách.

    Không dùng FK cho head_user_id để tránh phụ thuộc vòng với User ở tầng
    schema — ràng buộc "head phải có role DEPARTMENT_HEAD" kiểm tra ở service.
    """

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    name: str = Field(unique=True)
    head_user_id: UUID | None = Field(default=None, index=True)
