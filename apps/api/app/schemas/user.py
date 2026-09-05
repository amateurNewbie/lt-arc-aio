from uuid import UUID

from sqlmodel import SQLModel

from app.core.permissions import Role


class UserCreate(SQLModel):
    email: str
    password: str
    role: Role
    full_name: str | None = None
    department_id: UUID | None = None


class UserRead(SQLModel):
    id: UUID
    email: str
    full_name: str | None
    role: Role
    department_id: UUID | None
