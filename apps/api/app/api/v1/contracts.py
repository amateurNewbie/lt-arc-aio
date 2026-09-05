from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.deps import get_current_user, get_session, require_roles
from app.core.permissions import PermissionGroup, Role
from app.models.contract import Contract, ContractMilestone
from app.models.user import User
from app.schemas.contract import (
    ContractCreate,
    ContractMilestoneRead,
    ContractRead,
    MilestoneCollectRequest,
)
from app.schemas.payment import PaymentRead
from app.services.contract_service import (
    InvalidMilestoneRatioError,
    create_contract,
    get_milestones,
    list_all_contracts,
    list_by_project,
)
from app.services.payment_service import MilestoneOverpaidError, collect_milestone
from app.services.permission_service import has_permission

router = APIRouter(tags=["contracts"])


async def _to_read(session: AsyncSession, contract: Contract) -> ContractRead:
    milestones = await get_milestones(session, contract.id)
    return ContractRead(
        **contract.model_dump(),
        milestones=[ContractMilestoneRead(**m.model_dump()) for m in milestones],
    )


@router.get("/api/contracts", response_model=list[ContractRead])
async def list_all_contracts_endpoint(
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(get_current_user),
) -> list[ContractRead]:
    """FR-9 — trang Hợp đồng toàn công ty (không giới hạn theo 1 dự án)."""
    contracts = await list_all_contracts(session)
    return [await _to_read(session, c) for c in contracts]


@router.get("/api/projects/{project_id}/contracts", response_model=list[ContractRead])
async def list_contracts_endpoint(
    project_id: UUID,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(get_current_user),
) -> list[ContractRead]:
    contracts = await list_by_project(session, project_id)
    return [await _to_read(session, c) for c in contracts]


@router.post("/api/projects/{project_id}/contracts", response_model=ContractRead, status_code=status.HTTP_201_CREATED)
async def create_contract_endpoint(
    project_id: UUID,
    payload: ContractCreate,
    session: AsyncSession = Depends(get_session),
    admin: User = Depends(require_roles(Role.ADMIN, Role.DIRECTOR)),
) -> ContractRead:
    """FR-9.1/9.2 — chỉ Admin/Giám đốc tạo hợp đồng; tổng tỷ lệ đợt phải = 100%."""
    try:
        contract = await create_contract(
            session,
            project_id=project_id,
            type_=payload.type,
            value=payload.value,
            milestones=[m.model_dump() for m in payload.milestones],
            actor=admin,
            signed_date=payload.signed_date,
            due_date=payload.due_date,
        )
    except InvalidMilestoneRatioError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc)) from exc
    return await _to_read(session, contract)


@router.get("/api/contracts/{contract_id}/milestones", response_model=list[ContractMilestoneRead])
async def list_milestones_endpoint(
    contract_id: UUID,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(get_current_user),
) -> list[ContractMilestone]:
    return await get_milestones(session, contract_id)


@router.post("/api/contracts/{contract_id}/milestones/{milestone_id}/collect", response_model=PaymentRead)
async def collect_milestone_endpoint(
    contract_id: UUID,
    milestone_id: UUID,
    payload: MilestoneCollectRequest,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
):
    """FR-9.3/Phụ lục A — ADMIN/DIRECTOR mặc định; người khác cần được cấp
    nhóm quyền CONTRACTS_COLLECT (FR-1.7) trên đúng dự án của hợp đồng này."""
    contract = await session.get(Contract, contract_id)
    milestone = await session.get(ContractMilestone, milestone_id)
    if contract is None or milestone is None or milestone.contract_id != contract_id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Contract or milestone not found")

    if not await has_permission(session, user, PermissionGroup.CONTRACTS_COLLECT, contract.project_id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Missing permission group CONTRACTS_COLLECT")

    try:
        payment = await collect_milestone(
            session,
            milestone,
            project_id=contract.project_id,
            amount=payload.amount,
            fund_account_id=payload.fund_account_id,
            actor=user,
            on=payload.date,
        )
    except MilestoneOverpaidError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc)) from exc
    return payment
