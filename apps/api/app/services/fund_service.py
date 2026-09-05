from uuid import UUID

from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.models.enums import FundType
from app.models.fund import CashLedgerEntry, FundAccount


async def create_fund(session: AsyncSession, *, name: str, type_: FundType, balance: int = 0) -> FundAccount:
    """FR-12.1 — số dư ban đầu do ADMIN/DIRECTOR nhập (kiểm tra ở router)."""
    fund = FundAccount(name=name, type=type_, balance=balance)
    session.add(fund)
    await session.commit()
    await session.refresh(fund)
    return fund


async def list_funds(session: AsyncSession) -> list[FundAccount]:
    result = await session.exec(select(FundAccount))
    return list(result.all())


async def get_ledger(session: AsyncSession, fund_account_id: UUID) -> list[CashLedgerEntry]:
    """FR-12.3 — sổ quỹ chi tiết."""
    result = await session.exec(
        select(CashLedgerEntry).where(CashLedgerEntry.fund_account_id == fund_account_id).order_by(CashLedgerEntry.date.desc())
    )
    return list(result.all())
