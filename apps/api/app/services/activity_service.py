from uuid import UUID

from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.permissions import Role
from app.models.activity import Activity
from app.models.project import ProjectDepartmentHead
from app.models.user import User


async def log_activity(
    session: AsyncSession,
    *,
    icon: str,
    title: str,
    user_id: UUID,
    project_id: UUID | None = None,
) -> Activity:
    """FR-18.1 — hệ thống tự ghi, không có endpoint cho user tạo thủ công."""
    activity = Activity(icon=icon, title=title, user_id=user_id, project_id=project_id)
    session.add(activity)
    await session.commit()
    await session.refresh(activity)
    return activity


async def list_recent_activities(session: AsyncSession, actor: User, limit: int = 50) -> list[Activity]:
    """FR-18.2 — Trưởng bộ phận chỉ thấy hoạt động của dự án mình phụ trách;
    Nhân viên chỉ thấy hoạt động của chính mình; Admin/Giám đốc thấy toàn bộ."""
    query = select(Activity).order_by(Activity.created_at.desc()).limit(limit)

    if actor.role == Role.EMPLOYEE:
        query = query.where(Activity.user_id == actor.id)
    elif actor.role == Role.DEPARTMENT_HEAD:
        own_projects = select(ProjectDepartmentHead.project_id).where(ProjectDepartmentHead.user_id == actor.id)
        query = query.where(Activity.project_id.in_(own_projects))

    result = await session.exec(query)
    return list(result.all())
