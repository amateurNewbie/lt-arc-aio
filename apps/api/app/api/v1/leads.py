from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.deps import get_current_user, get_session, require_roles
from app.core.permissions import Role
from app.models.enums import LeadStatus
from app.models.lead import Lead
from app.models.user import User
from app.schemas.lead import LeadConvertRequest, LeadCreate, LeadRead, LeadUpdate
from app.schemas.project import ProjectRead
from app.services.lead_service import (
    InvalidLeadStatusTransitionError,
    LeadAlreadyConvertedError,
    convert_to_project,
    create_lead,
    list_leads,
    update_lead_status,
)

router = APIRouter(prefix="/api/leads", tags=["leads"])


@router.get("", response_model=list[LeadRead])
async def list_leads_endpoint(
    status_filter: LeadStatus | None = None,
    source: str | None = None,
    owner_id: UUID | None = None,
    search: str | None = None,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
) -> list[Lead]:
    """FR-2.4 — mỗi người chỉ thấy khách hàng tiềm năng mình phụ trách, trừ Admin thấy hết."""
    return await list_leads(session, user, status=status_filter, source=source, owner_id=owner_id, search=search)


@router.post("", response_model=LeadRead, status_code=status.HTTP_201_CREATED)
async def create_lead_endpoint(
    payload: LeadCreate,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> Lead:
    return await create_lead(
        session,
        name=payload.name,
        owner_id=payload.owner_id or user.id,
        phone=payload.phone,
        email=payload.email,
        need=payload.need,
        budget_estimate=payload.budget_estimate,
        source=payload.source,
        note=payload.note,
    )


@router.patch("/{lead_id}", response_model=LeadRead)
async def update_lead_endpoint(
    lead_id: UUID,
    payload: LeadUpdate,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
) -> Lead:
    """RBAC — Admin sửa được mọi lead; người khác chỉ sửa được lead mình phụ trách."""
    lead = await session.get(Lead, lead_id)
    if lead is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Lead not found")
    if user.role != Role.ADMIN and lead.owner_id != user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Chỉ được sửa khách hàng tiềm năng mình phụ trách")

    if payload.status is not None:
        try:
            lead = await update_lead_status(session, lead, status=payload.status, actor=user, note=payload.note)
        except InvalidLeadStatusTransitionError as exc:
            raise HTTPException(status.HTTP_409_CONFLICT, str(exc)) from exc

    field_updates = payload.model_dump(exclude={"status", "note"}, exclude_unset=True)
    if field_updates:
        for field, value in field_updates.items():
            setattr(lead, field, value)
        session.add(lead)
        await session.commit()
        await session.refresh(lead)
    return lead


@router.delete("/{lead_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_lead_endpoint(
    lead_id: UUID,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
) -> None:
    """RBAC — Admin xoá được mọi lead; người khác chỉ xoá được lead mình phụ trách."""
    lead = await session.get(Lead, lead_id)
    if lead is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Lead not found")
    if user.role != Role.ADMIN and lead.owner_id != user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Chỉ được xoá khách hàng tiềm năng mình phụ trách")
    await session.delete(lead)
    await session.commit()


@router.post("/{lead_id}/convert", response_model=dict)
async def convert_lead_endpoint(
    lead_id: UUID,
    payload: LeadConvertRequest,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> dict:
    """FR-2.3 — chỉ Admin/Giám đốc chốt lead thành dự án."""
    lead = await session.get(Lead, lead_id)
    if lead is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Lead not found")
    try:
        lead, project = await convert_to_project(
            session,
            lead,
            actor=user,
            category=payload.category,
            manager_id=payload.manager_id,
            type_=payload.type,
            area=payload.area,
            budget=payload.budget,
        )
    except LeadAlreadyConvertedError as exc:
        raise HTTPException(status.HTTP_409_CONFLICT, "Lead already converted") from exc

    return {"lead": LeadRead.model_validate(lead), "project": ProjectRead.model_validate(project)}
