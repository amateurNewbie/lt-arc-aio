from fastapi import APIRouter, Depends
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.deps import get_session, require_roles
from app.core.permissions import Role
from app.models.project import ProjectDepartmentHead
from app.models.user import User
from app.schemas.receivable import ReceivableRead
from app.services.contract_service import list_receivables

router = APIRouter(prefix="/api/receivables", tags=["receivables"])


@router.get("", response_model=list[ReceivableRead])
async def list_receivables_endpoint(
    session: AsyncSession = Depends(get_session),
    user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR, Role.DEPARTMENT_HEAD)),
) -> list[ReceivableRead]:
    """FR-10.1; RBAC §2.6 — Trưởng bộ phận chỉ xem dự án mình phụ trách."""
    receivables = await list_receivables(session)
    if user.role == Role.DEPARTMENT_HEAD:
        result = await session.exec(select(ProjectDepartmentHead.project_id).where(ProjectDepartmentHead.user_id == user.id))
        own_project_ids = set(result.all())
        receivables = [r for r in receivables if r["project_id"] in own_project_ids]
    return [ReceivableRead(**r) for r in receivables]
