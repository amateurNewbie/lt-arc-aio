from uuid import UUID

from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.clock import utcnow
from app.models.budget import BudgetEstimate, BudgetEstimateLine
from app.models.enums import BudgetEstimateStatus
from app.models.user import User
from app.services.activity_service import log_activity


class InvalidBudgetTransitionError(Exception):
    pass


async def _latest_version(session: AsyncSession, project_id: UUID) -> int:
    result = await session.exec(
        select(BudgetEstimate.version).where(BudgetEstimate.project_id == project_id).order_by(BudgetEstimate.version.desc())
    )
    latest = result.first()
    return (latest or 0) + 1


async def create_draft(
    session: AsyncSession,
    *,
    project_id: UUID,
    lines: list[dict],
) -> BudgetEstimate:
    """FR-4.1/4.2 — lập dự toán mới (Nháp), phiên bản tự tăng theo dự án."""
    version = await _latest_version(session, project_id)
    budget = BudgetEstimate(project_id=project_id, version=version, status=BudgetEstimateStatus.DRAFT)
    session.add(budget)
    await session.flush()

    for line in lines:
        amount = round(line["quantity"] * line["unit_price"])
        session.add(
            BudgetEstimateLine(
                budget_estimate_id=budget.id,
                cost_category_id=line["cost_category_id"],
                description=line.get("description"),
                unit=line["unit"],
                quantity=line["quantity"],
                unit_price=line["unit_price"],
                amount=amount,
            )
        )
    await session.commit()
    await session.refresh(budget)
    return budget


async def submit(session: AsyncSession, budget: BudgetEstimate, actor: User) -> BudgetEstimate:
    """FR-4.2 — Nháp → Chờ duyệt."""
    if budget.status != BudgetEstimateStatus.DRAFT:
        raise InvalidBudgetTransitionError("Chỉ dự toán ở trạng thái Nháp mới gửi duyệt được")
    budget.status = BudgetEstimateStatus.PENDING
    session.add(budget)
    await session.commit()
    await session.refresh(budget)
    await log_activity(
        session,
        icon="file-check",
        title=f"Gửi duyệt dự toán v{budget.version}",
        user_id=actor.id,
        project_id=budget.project_id,
    )
    return budget


async def approve(session: AsyncSession, budget: BudgetEstimate, actor: User) -> BudgetEstimate:
    """FR-4.2 — chỉ ADMIN/DIRECTOR duyệt, không có ngưỡng tự duyệt."""
    if budget.status != BudgetEstimateStatus.PENDING:
        raise InvalidBudgetTransitionError("Chỉ dự toán Chờ duyệt mới duyệt được")
    budget.status = BudgetEstimateStatus.APPROVED
    budget.approved_by_id = actor.id
    budget.approved_at = utcnow()
    session.add(budget)
    await session.commit()
    await session.refresh(budget)
    await log_activity(
        session,
        icon="badge-check",
        title=f"Duyệt dự toán v{budget.version}",
        user_id=actor.id,
        project_id=budget.project_id,
    )
    return budget


async def get_lines(session: AsyncSession, budget_estimate_id: UUID) -> list[BudgetEstimateLine]:
    result = await session.exec(select(BudgetEstimateLine).where(BudgetEstimateLine.budget_estimate_id == budget_estimate_id))
    return list(result.all())


async def get_latest_approved(session: AsyncSession, project_id: UUID) -> BudgetEstimate | None:
    """FR-4.4 — dự toán đã duyệt làm cơ sở đối chiếu chi phí thực tế."""
    result = await session.exec(
        select(BudgetEstimate)
        .where(BudgetEstimate.project_id == project_id, BudgetEstimate.status == BudgetEstimateStatus.APPROVED)
        .order_by(BudgetEstimate.version.desc())
    )
    return result.first()


async def list_by_project(session: AsyncSession, project_id: UUID) -> list[BudgetEstimate]:
    result = await session.exec(
        select(BudgetEstimate).where(BudgetEstimate.project_id == project_id).order_by(BudgetEstimate.version.desc())
    )
    return list(result.all())
