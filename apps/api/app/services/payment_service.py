from datetime import date
from uuid import UUID

from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.clock import utcnow
from app.models.contract import ContractMilestone
from app.models.enums import MilestoneStatus
from app.models.fund import CashLedgerEntry, FundAccount
from app.models.payment import Payment
from app.models.user import User
from app.services.activity_service import log_activity


class MilestoneOverpaidError(Exception):
    pass


async def collect_milestone(
    session: AsyncSession,
    milestone: ContractMilestone,
    *,
    project_id: UUID,
    amount: int,
    fund_account_id: UUID,
    actor: User,
    on: date | None = None,
) -> Payment:
    """FR-9.3/FR-12.2 — ghi 1 Payment + 1 CashLedgerEntry + cập nhật milestone,
    trong cùng 1 transaction (chưa commit tới khi mọi thứ hợp lệ) — invariant #3.
    """
    remaining = milestone.amount - milestone.paid_amount
    if amount > remaining:
        raise MilestoneOverpaidError(f"Số tiền thu ({amount:,}) vượt phần còn lại ({remaining:,})")

    fund = await session.get(FundAccount, fund_account_id)
    if fund is None:
        raise ValueError("Fund account not found")

    payment_date = on or utcnow().date()

    payment = Payment(
        project_id=project_id,
        contract_milestone_id=milestone.id,
        amount=amount,
        date=payment_date,
        note=f"Thu đợt {milestone.name}",
        fund_account_id=fund_account_id,
        recorded_by_id=actor.id,
    )
    session.add(payment)
    await session.flush()

    session.add(
        CashLedgerEntry(
            fund_account_id=fund_account_id,
            date=payment_date,
            description=f"Thu đợt {milestone.name}",
            inflow=amount,
            outflow=0,
            source_type="payment",
            source_id=payment.id,
            recorded_by_id=actor.id,
        )
    )

    milestone.paid_amount += amount
    milestone.status = MilestoneStatus.PAID if milestone.paid_amount >= milestone.amount else MilestoneStatus.PARTIALLY_PAID
    session.add(milestone)

    fund.balance += amount
    session.add(fund)

    await session.commit()
    await session.refresh(payment)

    await log_activity(
        session,
        icon="hand",
        title=f"Thu {amount:,} ₫ — đợt {milestone.name}",
        user_id=actor.id,
        project_id=project_id,
    )
    return payment


async def create_project_payment(
    session: AsyncSession,
    *,
    project_id: UUID,
    amount: int,
    fund_account_id: UUID,
    actor: User,
    on: date | None = None,
    note: str | None = None,
    contract_milestone_id: UUID | None = None,
) -> Payment:
    """Thu tự do trên dự án; nếu có milestone thì cập nhật thêm như collect."""
    if amount <= 0:
        raise ValueError("Số tiền phải > 0")

    if contract_milestone_id is not None:
        milestone = await session.get(ContractMilestone, contract_milestone_id)
        if milestone is None:
            raise ValueError("Milestone not found")
        return await collect_milestone(
            session,
            milestone,
            project_id=project_id,
            amount=amount,
            fund_account_id=fund_account_id,
            actor=actor,
            on=on,
        )

    fund = await session.get(FundAccount, fund_account_id)
    if fund is None:
        raise ValueError("Fund account not found")

    payment_date = on or utcnow().date()
    payment = Payment(
        project_id=project_id,
        contract_milestone_id=None,
        amount=amount,
        date=payment_date,
        note=note,
        fund_account_id=fund_account_id,
        recorded_by_id=actor.id,
    )
    session.add(payment)
    await session.flush()

    session.add(
        CashLedgerEntry(
            fund_account_id=fund_account_id,
            date=payment_date,
            description=note or "Thu dự án",
            inflow=amount,
            outflow=0,
            source_type="payment",
            source_id=payment.id,
            recorded_by_id=actor.id,
        )
    )
    fund.balance += amount
    session.add(fund)

    await session.commit()
    await session.refresh(payment)
    await log_activity(
        session,
        icon="hand",
        title=f"Thu {amount:,} ₫ — {note or 'thu dự án'}",
        user_id=actor.id,
        project_id=project_id,
    )
    return payment
