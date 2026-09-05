from datetime import datetime
from uuid import UUID, uuid4

from sqlmodel import Field, SQLModel

from app.core.clock import utcnow
from app.core.permissions import Role


class User(SQLModel, table=True):
    """FR-1 — tài khoản người dùng và vai trò."""

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    email: str = Field(unique=True, index=True)
    full_name: str | None = Field(default=None)
    password_hash: str
    role: Role
    department_id: UUID | None = Field(default=None, foreign_key="department.id", index=True)

    failed_login_count: int = Field(default=0)
    locked_until: datetime | None = Field(default=None)
    last_active_at: datetime | None = Field(default=None)

    created_at: datetime = Field(default_factory=utcnow)
