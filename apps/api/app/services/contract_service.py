from uuid import UUID

from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.models.contract import Contract, ContractMilestone
from app.models.enums import ProjectCategory
from app.models.project import Project
from app.models.user import User
from app.services.activity_service import log_activity


class InvalidMilestoneRatioError(Exception):
    pass


async def generate_contract_code(session: AsyncSession, project: Project) -> str:
    """Mã HĐ theo mã dự án; thêm hậu tố -02, -03… nếu đã có HĐ cùng base."""
    base = f"HD-{project.code.removeprefix('LT-')}"
    result = await session.exec(select(Contract).where(Contract.project_id == project.id))
    existing = list(result.all())
    if not existing:
        return base
    return f"{base}-{len(existing) + 1:02d}"


async def create_contract(
    session: AsyncSession,
    *,
    project_id: UUID,
    type_: ProjectCategory,
    value: int,
    milestones: list[dict],
    actor: User,
    signed_date=None,
    due_date=None,
) -> Contract:
    """FR-9.2 — tổng tỷ lệ các đợt (kể cả giữ bảo hành) phải bằng 100%."""
    total_ratio = sum(m["ratio"] for m in milestones)
    if abs(total_ratio - 100.0) > 0.01:
        raise InvalidMilestoneRatioError(f"Tổng tỷ lệ các đợt phải bằng 100%, hiện tại {total_ratio}%")

    project = await session.get(Project, project_id)
    code = await generate_contract_code(session, project)

    contract = Contract(
        project_id=project_id,
        code=code,
        type=type_,
        value=value,
        signed_date=signed_date,
        due_date=due_date,
    )
    session.add(contract)
    await session.flush()

    for m in milestones:
        amount = round(value * m["ratio"] / 100)
        session.add(
            ContractMilestone(
                contract_id=contract.id,
                name=m["name"],
                condition=m.get("condition"),
                ratio=m["ratio"],
                amount=amount,
                due_date=m.get("due_date"),
                is_retention=m.get("is_retention", False),
            )
        )
    await session.commit()
    await session.refresh(contract)
    await log_activity(
        session,
        icon="file-signature",
        title=f"Tạo hợp đồng {contract.code}",
        user_id=actor.id,
        project_id=project_id,
    )
    return contract


async def get_milestones(session: AsyncSession, contract_id: UUID) -> list[ContractMilestone]:
    result = await session.exec(select(ContractMilestone).where(ContractMilestone.contract_id == contract_id))
    return list(result.all())


async def list_by_project(session: AsyncSession, project_id: UUID) -> list[Contract]:
    result = await session.exec(select(Contract).where(Contract.project_id == project_id))
    return list(result.all())


async def list_all_contracts(session: AsyncSession) -> list[Contract]:
    """FR-9 — danh sách hợp đồng toàn công ty, không giới hạn theo dự án."""
    result = await session.exec(select(Contract))
    return list(result.all())


async def list_receivables(session: AsyncSession, project_id: UUID | None = None) -> list[dict]:
    """FR-10.1 — công nợ phải thu bám theo từng đợt thanh toán còn dở dang."""
    query = select(ContractMilestone, Contract).join(Contract, ContractMilestone.contract_id == Contract.id)
    if project_id is not None:
        query = query.where(Contract.project_id == project_id)

    result = await session.exec(query)
    receivables = []
    for milestone, contract in result.all():
        remaining = milestone.amount - milestone.paid_amount
        if remaining <= 0:
            continue
        receivables.append(
            {
                "milestone_id": milestone.id,
                "contract_id": contract.id,
                "project_id": contract.project_id,
                "milestone_name": milestone.name,
                "amount": milestone.amount,
                "paid_amount": milestone.paid_amount,
                "remaining": remaining,
                "due_date": milestone.due_date,
                "status": milestone.status,
            }
        )
    return receivables
