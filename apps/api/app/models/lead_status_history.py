from datetime import datetime
from uuid import UUID, uuid4

from sqlmodel import Field, SQLModel

from app.core.clock import utcnow
from app.models.enums import LeadStatus


class LeadStatusHistory(SQLModel, table=True):
    """Lịch sử chuyển trạng thái khách hàng tiềm năng — mỗi lần chuyển trạng
    thái ghi 1 dòng, kèm ghi chú của người thực hiện (FR-2.2)."""

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    lead_id: UUID = Field(foreign_key="lead.id", index=True)
    from_status: LeadStatus
    to_status: LeadStatus
    note: str | None = Field(default=None)
    actor_id: UUID = Field(foreign_key="user.id")
    created_at: datetime = Field(default_factory=utcnow, index=True)
