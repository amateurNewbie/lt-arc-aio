from uuid import UUID

from sqlmodel import SQLModel, select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.models.project_stage_template import ProjectStageTemplate


class StageTemplateCreate(SQLModel):
    key: str
    name: str
    sort_order: int = 0


class StageTemplateUpdate(SQLModel):
    name: str | None = None
    sort_order: int | None = None
    active: bool | None = None


class StageTemplateRead(SQLModel):
    id: UUID
    key: str
    name: str
    sort_order: int
    active: bool


async def list_templates(session: AsyncSession, *, active_only: bool = False) -> list[ProjectStageTemplate]:
    query = select(ProjectStageTemplate).order_by(ProjectStageTemplate.sort_order, ProjectStageTemplate.name)
    if active_only:
        query = query.where(ProjectStageTemplate.active == True)  # noqa: E712
    result = await session.exec(query)
    return list(result.all())


async def create_template(session: AsyncSession, *, key: str, name: str, sort_order: int = 0) -> ProjectStageTemplate:
    import re

    clean_key = key.strip().lower().replace(" ", "_")
    clean_key = re.sub(r"[^a-z0-9_]", "", clean_key) or f"stage_{sort_order}"
    row = ProjectStageTemplate(key=clean_key, name=name.strip(), sort_order=sort_order)
    session.add(row)
    await session.commit()
    await session.refresh(row)
    return row


async def update_template(
    session: AsyncSession,
    template: ProjectStageTemplate,
    *,
    name: str | None = None,
    sort_order: int | None = None,
    active: bool | None = None,
) -> ProjectStageTemplate:
    if name is not None:
        template.name = name.strip()
    if sort_order is not None:
        template.sort_order = sort_order
    if active is not None:
        template.active = active
    session.add(template)
    await session.commit()
    await session.refresh(template)
    return template


async def delete_template(session: AsyncSession, template: ProjectStageTemplate) -> None:
    await session.delete(template)
    await session.commit()


async def active_template_keys(session: AsyncSession) -> list[str]:
    rows = await list_templates(session, active_only=True)
    return [r.key for r in rows]
