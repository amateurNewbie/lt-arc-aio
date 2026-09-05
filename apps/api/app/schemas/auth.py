from uuid import UUID

from sqlmodel import SQLModel

from app.core.permissions import Role


class LoginRequest(SQLModel):
    email: str
    password: str


class TokenResponse(SQLModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class MeResponse(SQLModel):
    id: UUID
    email: str
    full_name: str | None
    role: Role
    department_id: UUID | None


class PreviewRoleRequest(SQLModel):
    role: Role


class PreviewRoleResponse(SQLModel):
    access_token: str
    token_type: str = "bearer"
