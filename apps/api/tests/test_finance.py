from datetime import date

from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.permissions import Role
from app.models.enums import (
    AllocationBasis,
    BudgetEstimateStatus,
    CostCategoryScope,
    FundType,
    ProjectCategory,
)
from app.services.auth_service import create_user
from app.services.budget_service import InvalidBudgetTransitionError, approve, create_draft, submit
from app.services.contract_service import InvalidMilestoneRatioError, create_contract
from app.services.cost_category_service import create_category
from app.services.fund_service import create_fund
from app.services.overhead_service import AllocationAlreadyAppliedError, apply_allocation, declare_cost
from app.services.payment_service import MilestoneOverpaidError, collect_milestone
from app.services.pnl_service import project_pnl
from app.services.project_cost_service import DuplicateCostWarning, InvalidCostCategoryError, create_cost
from app.services.project_service import create_project


async def _project(session: AsyncSession, director):
    return await create_project(
        session, name="Biệt thự Test", client="KH Test", category=ProjectCategory.CONSTRUCTION, manager_id=director.id, actor=director
    )


async def test_budget_approval_workflow(session: AsyncSession) -> None:
    """FR-4.2 — Nháp → Chờ duyệt → Đã duyệt; không có ngưỡng tự duyệt."""
    director = await create_user(session, email="fin1@ltarc.vn", password="x", role=Role.DIRECTOR)
    project = await _project(session, director)
    category = await create_category(session, name="Vật tư Test", scope=CostCategoryScope.PROJECT, description=None)

    budget = await create_draft(
        session,
        project_id=project.id,
        lines=[{"cost_category_id": category.id, "unit": "m2", "quantity": 100, "unit_price": 500_000, "description": None}],
    )
    assert budget.status == BudgetEstimateStatus.DRAFT

    try:
        await approve(session, budget, director)
        assert False, "expected InvalidBudgetTransitionError — chưa submit"
    except InvalidBudgetTransitionError:
        pass

    budget = await submit(session, budget, director)
    assert budget.status == BudgetEstimateStatus.PENDING

    budget = await approve(session, budget, director)
    assert budget.status == BudgetEstimateStatus.APPROVED
    assert budget.approved_by_id == director.id


async def test_project_cost_requires_project_scope_category(session: AsyncSession) -> None:
    """FR-6.2 — Chi bắt buộc gắn hạng mục chi phí phạm vi PROJECT."""
    director = await create_user(session, email="fin2@ltarc.vn", password="x", role=Role.DIRECTOR)
    project = await _project(session, director)
    company_category = await create_category(session, name="Marketing Test", scope=CostCategoryScope.COMPANY, description=None)

    try:
        await create_cost(session, project_id=project.id, cost_category_id=company_category.id, amount=1_000_000, actor=director)
        assert False, "expected InvalidCostCategoryError"
    except InvalidCostCategoryError:
        pass


async def test_duplicate_cost_warning_then_confirm(session: AsyncSession) -> None:
    """FR-6.6 — cảnh báo trùng trong ±3 ngày; confirm_duplicate=True thì vẫn lưu được."""
    director = await create_user(session, email="fin3@ltarc.vn", password="x", role=Role.DIRECTOR)
    project = await _project(session, director)
    category = await create_category(session, name="Nhân công Test", scope=CostCategoryScope.PROJECT, description=None)

    first = await create_cost(session, project_id=project.id, cost_category_id=category.id, amount=2_000_000, actor=director, on=date(2026, 6, 1))

    try:
        await create_cost(session, project_id=project.id, cost_category_id=category.id, amount=2_000_000, actor=director, on=date(2026, 6, 2))
        assert False, "expected DuplicateCostWarning"
    except DuplicateCostWarning as w:
        assert w.existing.id == first.id

    second = await create_cost(
        session, project_id=project.id, cost_category_id=category.id, amount=2_000_000, actor=director, on=date(2026, 6, 2), confirm_duplicate=True
    )
    assert second.id != first.id


async def test_contract_milestones_must_sum_to_100_percent(session: AsyncSession) -> None:
    """FR-9.2 — tổng tỷ lệ các đợt (kể cả giữ bảo hành) phải bằng 100%."""
    director = await create_user(session, email="fin4@ltarc.vn", password="x", role=Role.DIRECTOR)
    project = await _project(session, director)

    try:
        await create_contract(
            session,
            project_id=project.id,
            type_=ProjectCategory.CONSTRUCTION,
            value=1_000_000_000,
            milestones=[{"name": "Đợt 1", "ratio": 50}, {"name": "Đợt 2", "ratio": 40}],
            actor=director,
        )
        assert False, "expected InvalidMilestoneRatioError"
    except InvalidMilestoneRatioError:
        pass

    contract = await create_contract(
        session,
        project_id=project.id,
        type_=ProjectCategory.CONSTRUCTION,
        value=1_000_000_000,
        milestones=[{"name": "Đợt 1", "ratio": 50}, {"name": "Đợt 2", "ratio": 45}, {"name": "Bảo hành", "ratio": 5, "is_retention": True}],
        actor=director,
    )
    assert contract.value == 1_000_000_000


async def test_collect_milestone_atomic_and_overpay_guard(session: AsyncSession) -> None:
    """Invariant #3 — 1 Payment + 1 CashLedgerEntry + cập nhật milestone, atomic; không thu vượt."""
    director = await create_user(session, email="fin5@ltarc.vn", password="x", role=Role.DIRECTOR)
    project = await _project(session, director)
    fund = await create_fund(session, name="Quỹ tiền mặt Test", type_=FundType.CASH, balance=0)

    contract = await create_contract(
        session,
        project_id=project.id,
        type_=ProjectCategory.CONSTRUCTION,
        value=1_000_000_000,
        milestones=[{"name": "Đợt 1", "ratio": 100}],
        actor=director,
    )
    from app.services.contract_service import get_milestones

    milestone = (await get_milestones(session, contract.id))[0]
    assert milestone.amount == 1_000_000_000

    try:
        await collect_milestone(
            session, milestone, project_id=project.id, amount=2_000_000_000, fund_account_id=fund.id, actor=director
        )
        assert False, "expected MilestoneOverpaidError"
    except MilestoneOverpaidError:
        pass

    payment = await collect_milestone(
        session, milestone, project_id=project.id, amount=1_000_000_000, fund_account_id=fund.id, actor=director
    )
    assert payment.amount == 1_000_000_000

    await session.refresh(fund)
    await session.refresh(milestone)
    assert fund.balance == 1_000_000_000
    assert milestone.paid_amount == 1_000_000_000

    pnl = await project_pnl(session, project.id)
    assert pnl["revenue"] == 1_000_000_000


async def test_overhead_allocation_idempotent(session: AsyncSession) -> None:
    """FR-8.3 — apply idempotent theo tháng, không tính trùng lần 2."""
    director = await create_user(session, email="fin6@ltarc.vn", password="x", role=Role.DIRECTOR)
    project = await _project(session, director)
    fund = await create_fund(session, name="Quỹ Test OH", type_=FundType.CASH, balance=0)
    company_category = await create_category(session, name="Thuê VP Test", scope=CostCategoryScope.COMPANY, description=None)

    await declare_cost(session, cost_category_id=company_category.id, amount=100_000_000, on=date(2026, 6, 1), month="2026-06")

    contract = await create_contract(
        session, project_id=project.id, type_=ProjectCategory.CONSTRUCTION, value=500_000_000, milestones=[{"name": "Đợt 1", "ratio": 100}], actor=director
    )
    from app.services.contract_service import get_milestones

    milestone = (await get_milestones(session, contract.id))[0]
    await collect_milestone(session, milestone, project_id=project.id, amount=500_000_000, fund_account_id=fund.id, actor=director, on=date(2026, 6, 5))

    allocations = await apply_allocation(session, "2026-06", AllocationBasis.REVENUE, director)
    assert len(allocations) == 1
    assert allocations[0].allocated_amount == 100_000_000  # dự án duy nhất có doanh thu -> nhận 100%

    try:
        await apply_allocation(session, "2026-06", AllocationBasis.REVENUE, director)
        assert False, "expected AllocationAlreadyAppliedError"
    except AllocationAlreadyAppliedError:
        pass
