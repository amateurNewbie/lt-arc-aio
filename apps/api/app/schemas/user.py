from uuid import UUID

from sqlmodel import SQLModel

from app.core.permissions import Role


class UserCreate(SQLModel):
    email: str
    password: str
    role: Role
    department_id: UUID | None = None


class UserRead(SQLModel):
    id: UUID
    email: str
    role: Role
    department_id: UUID | None
