from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.deps import get_session, require_roles
from app.core.permissions import Role
from app.models.department import Department
from app.models.user import User
from app.schemas.department import DepartmentCreate, DepartmentRead, DepartmentUpdate
from app.services.department_service import create_department, list_departments, update_department

router = APIRouter(prefix="/api/departments", tags=["departments"])


@router.get("", response_model=list[DepartmentRead])
async def list_departments_endpoint(
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR, Role.DEPARTMENT_HEAD)),
) -> list[DepartmentRead]:
    return await list_departments(session)


@router.post("", response_model=DepartmentRead, status_code=status.HTTP_201_CREATED)
async def create_department_endpoint(
    payload: DepartmentCreate,
    session: AsyncSession = Depends(get_session),
    _admin: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> DepartmentRead:
    """FR-13.1 — chỉ Admin/Giám đốc tạo bộ phận."""
    return await create_department(session, name=payload.name, head_user_id=payload.head_user_id)


@router.patch("/{department_id}", response_model=DepartmentRead)
async def update_department_endpoint(
    department_id: UUID,
    payload: DepartmentUpdate,
    session: AsyncSession = Depends(get_session),
    _admin: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> DepartmentRead:
    department = await session.get(Department, department_id)
    if department is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Department not found")
    return await update_department(session, department, name=payload.name, head_user_id=payload.head_user_id)
