from uuid import UUID

from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.permissions import Role
from app.models.enums import LeadStatus, ProjectCategory
from app.models.lead import Lead
from app.models.user import User
from app.services.activity_service import log_activity
from app.services.project_service import create_project


class LeadAlreadyConvertedError(Exception):
    pass


async def create_lead(
    session: AsyncSession,
    *,
    name: str,
    owner_id: UUID,
    phone: str | None = None,
    email: str | None = None,
    need: str | None = None,
    budget_estimate: int | None = None,
    source: str | None = None,
    note: str | None = None,
) -> Lead:
    """FR-2.1 — người phụ trách mặc định là người tạo."""
    lead = Lead(
        name=name,
        phone=phone,
        email=email,
        need=need,
        budget_estimate=budget_estimate,
        source=source,
        note=note,
        owner_id=owner_id,
    )
    session.add(lead)
    await session.commit()
    await session.refresh(lead)
    return lead


async def list_leads(
    session: AsyncSession,
    actor: User,
    *,
    status: LeadStatus | None = None,
    source: str | None = None,
    owner_id: UUID | None = None,
    search: str | None = None,
) -> list[Lead]:
    """FR-2.4; RBAC §2.6 — Trưởng bộ phận chỉ xem lead của người trong bộ phận mình."""
    query = select(Lead)

    if actor.role == Role.DEPARTMENT_HEAD:
        dept_user_ids = select(User.id).where(User.department_id == actor.department_id)
        query = query.where(Lead.owner_id.in_(dept_user_ids))

    if status is not None:
        query = query.where(Lead.status == status)
    if source is not None:
        query = query.where(Lead.source == source)
    if owner_id is not None:
        query = query.where(Lead.owner_id == owner_id)
    if search:
        like = f"%{search}%"
        query = query.where((Lead.name.ilike(like)) | (Lead.phone.ilike(like)))

    result = await session.exec(query.order_by(Lead.created_at.desc()))
    return list(result.all())


async def update_lead_status(session: AsyncSession, lead: Lead, *, status: LeadStatus, actor: User) -> Lead:
    """FR-2.2 — chuyển trạng thái do người phụ trách hoặc Giám đốc/Admin."""
    old_status = lead.status
    lead.status = status
    session.add(lead)
    await session.commit()
    await session.refresh(lead)

    await log_activity(
        session,
        icon="users",
        title=f"Khách hàng tiềm năng {lead.name}: {old_status} → {status}",
        user_id=actor.id,
    )
    return lead


async def convert_to_project(
    session: AsyncSession,
    lead: Lead,
    *,
    actor: User,
    category: ProjectCategory,
    manager_id: UUID,
    type_: str | None = None,
    area: float | None = None,
    budget: int | None = None,
):
    """FR-2.3 — chốt lead thành dự án mới, giữ liên kết ngược để tham chiếu lịch sử."""
    if lead.status == LeadStatus.CONVERTED:
        raise LeadAlreadyConvertedError()

    project = await create_project(
        session,
        name=lead.name,
        client=lead.name,
        category=category,
        manager_id=manager_id,
        actor=actor,
        type_=type_,
        area=area,
        budget=budget or lead.budget_estimate,
        lead_id=lead.id,
    )

    lead.status = LeadStatus.CONVERTED
    lead.converted_project_id = project.id
    session.add(lead)
    await session.commit()
    await session.refresh(lead)

    await log_activity(
        session,
        icon="check",
        title=f"Chốt khách hàng tiềm năng {lead.name} → dự án {project.code}",
        user_id=actor.id,
        project_id=project.id,
    )
    return lead, project
