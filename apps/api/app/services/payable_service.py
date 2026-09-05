from uuid import UUID

from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.clock import utcnow
from app.models.enums import PayableStatus
from app.models.fund import CashLedgerEntry, FundAccount
from app.models.payable import Payable
from app.models.user import User


class PayableOverpaidError(Exception):
    pass


async def create_payable(
    session: AsyncSession,
    *,
    project_id: UUID,
    vendor_name: str,
    cost_category_id: UUID,
    total_amount: int,
    due_date=None,
) -> Payable:
    """FR-10.2 — công nợ phải trả nhà cung cấp/thầu phụ."""
    payable = Payable(
        project_id=project_id,
        vendor_name=vendor_name,
        cost_category_id=cost_category_id,
        total_amount=total_amount,
        due_date=due_date,
    )
    session.add(payable)
    await session.commit()
    await session.refresh(payable)
    return payable


async def settle(
    session: AsyncSession,
    payable: Payable,
    *,
    amount: int,
    fund_account_id: UUID,
    actor: User,
    on=None,
) -> Payable:
    """FR-10.3 — ghi thanh toán công nợ, tạo bút toán Sổ quỹ (FR-12)."""
    remaining = payable.total_amount - payable.paid_amount
    if amount > remaining:
        raise PayableOverpaidError(f"Số tiền trả ({amount:,}) vượt phần còn lại ({remaining:,})")

    fund = await session.get(FundAccount, fund_account_id)
    if fund is None:
        raise ValueError("Fund account not found")

    session.add(
        CashLedgerEntry(
            fund_account_id=fund_account_id,
            date=on or utcnow().date(),
            description=f"Trả nợ {payable.vendor_name}",
            inflow=0,
            outflow=amount,
            source_type="payable_settlement",
            source_id=payable.id,
            recorded_by_id=actor.id,
        )
    )

    payable.paid_amount += amount
    payable.status = PayableStatus.SETTLED if payable.paid_amount >= payable.total_amount else PayableStatus.PENDING
    session.add(payable)

    fund.balance -= amount
    session.add(fund)

    await session.commit()
    await session.refresh(payable)
    return payable


async def list_payables(session: AsyncSession, project_id: UUID | None = None) -> list[Payable]:
    query = select(Payable)
    if project_id is not None:
        query = query.where(Payable.project_id == project_id)
    result = await session.exec(query)
    return list(result.all())
