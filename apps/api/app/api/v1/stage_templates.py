from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.deps import get_current_user, get_session, require_roles
from app.core.permissions import Role
from app.models.project_stage_template import ProjectStageTemplate
from app.models.user import User
from app.services.stage_template_service import (
    StageTemplateCreate,
    StageTemplateRead,
    StageTemplateUpdate,
    create_template,
    delete_template,
    list_templates,
    update_template,
)

router = APIRouter(prefix="/api/project-stage-templates", tags=["project-stage-templates"])


@router.get("", response_model=list[StageTemplateRead])
async def list_stage_templates_endpoint(
    active_only: bool = False,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(get_current_user),
) -> list[ProjectStageTemplate]:
    return await list_templates(session, active_only=active_only)


@router.post("", response_model=StageTemplateRead, status_code=status.HTTP_201_CREATED)
async def create_stage_template_endpoint(
    payload: StageTemplateCreate,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> ProjectStageTemplate:
    if not payload.name.strip():
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Tên giai đoạn bắt buộc")
    try:
        return await create_template(session, key=payload.key or payload.name, name=payload.name, sort_order=payload.sort_order)
    except Exception as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Không tạo được giai đoạn: {exc}") from exc


@router.patch("/{template_id}", response_model=StageTemplateRead)
async def update_stage_template_endpoint(
    template_id: UUID,
    payload: StageTemplateUpdate,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> ProjectStageTemplate:
    template = await session.get(ProjectStageTemplate, template_id)
    if template is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Không tìm thấy giai đoạn")
    return await update_template(
        session,
        template,
        name=payload.name,
        sort_order=payload.sort_order,
        active=payload.active,
    )


@router.delete("/{template_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_stage_template_endpoint(
    template_id: UUID,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> None:
    template = await session.get(ProjectStageTemplate, template_id)
    if template is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Không tìm thấy giai đoạn")
    await delete_template(session, template)
