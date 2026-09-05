from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import BigInteger, Column, ForeignKey
from sqlalchemy import Uuid as SAUuid
from sqlmodel import Field, SQLModel

from app.core.clock import utcnow
from app.models.enums import LeadStatus


class Lead(SQLModel, table=True):
    """FR-2 — khách hàng tiềm năng."""

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    name: str
    phone: str | None = Field(default=None, index=True)
    email: str | None = Field(default=None)
    need: str | None = Field(default=None)
    budget_estimate: int | None = Field(default=None, sa_type=BigInteger)  # BIGINT VND
    source: str | None = Field(default=None)
    note: str | None = Field(default=None)

    owner_id: UUID = Field(foreign_key="user.id", index=True)
    status: LeadStatus = Field(default=LeadStatus.NEW, index=True)

    # `use_alter=True`: Lead <-> Project là FK vòng (project.lead_id cũng trỏ
    # ngược lại lead.id) — phá vòng bằng ALTER TABLE thêm constraint sau khi
    # cả hai bảng đã tồn tại, nếu không Alembic/Postgres không sắp được thứ
    # tự tạo bảng.
    converted_project_id: UUID | None = Field(
        default=None,
        sa_column=Column(SAUuid(), ForeignKey("project.id", use_alter=True, name="fk_lead_converted_project")),
    )

    created_at: datetime = Field(default_factory=utcnow)
