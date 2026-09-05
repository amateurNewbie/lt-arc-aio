from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.deps import get_session, require_perm
from app.core.permissions import PermissionGroup
from app.models.fund import CashLedgerEntry, FundAccount
from app.models.user import User
from app.schemas.fund import CashLedgerEntryRead, FundAccountCreate, FundAccountRead
from app.services.fund_service import create_fund, get_ledger, list_funds

router = APIRouter(tags=["funds"])


@router.get("/api/funds", response_model=list[FundAccountRead])
async def list_funds_endpoint(
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(require_perm(PermissionGroup.FUNDS)),
) -> list[FundAccount]:
    """FR-12.1 — Admin/Giám đốc hoặc người được cấp quyền FUNDS."""
    return await list_funds(session)


@router.post("/api/funds", response_model=FundAccountRead, status_code=status.HTTP_201_CREATED)
async def create_fund_endpoint(
    payload: FundAccountCreate,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(require_perm(PermissionGroup.FUNDS)),
) -> FundAccount:
    return await create_fund(session, name=payload.name, type_=payload.type, balance=payload.balance)


@router.get("/api/funds/{fund_id}/ledger", response_model=list[CashLedgerEntryRead])
async def fund_ledger_endpoint(
    fund_id: UUID,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(require_perm(PermissionGroup.FUNDS)),
) -> list[CashLedgerEntry]:
    """FR-12.3 — sổ quỹ chi tiết của một quỹ/tài khoản."""
    return await get_ledger(session, fund_id)
