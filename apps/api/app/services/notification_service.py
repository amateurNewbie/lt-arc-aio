from datetime import timedelta
from uuid import UUID

from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.clock import utcnow
from app.models.contract import Contract, ContractMilestone
from app.models.enums import MilestoneStatus, TaskStatus
from app.models.notification import Notification
from app.models.overhead import OverheadAllocation, OverheadCost
from app.models.project import Project
from app.models.task import Task
from app.models.user import User


async def create_notification(session: AsyncSession, *, user_id: UUID, title: str, message: str) -> Notification:
    notification = Notification(user_id=user_id, title=title, message=message)
    session.add(notification)
    await session.commit()
    await session.refresh(notification)
    return notification


async def list_for_user(session: AsyncSession, user: User, unread_only: bool = False) -> list[Notification]:
    """FR-19.1 — danh sách thông báo riêng cho từng người dùng."""
    query = select(Notification).where(Notification.user_id == user.id)
    if unread_only:
        query = query.where(Notification.read.is_(False))
    result = await session.exec(query.order_by(Notification.created_at.desc()))
    return list(result.all())


class NotificationForbiddenError(Exception):
    pass


async def mark_read(session: AsyncSession, notification: Notification, user: User) -> Notification:
    """FR-19.3 — người dùng chỉ đánh dấu được thông báo của chính mình."""
    if notification.user_id != user.id:
        raise NotificationForbiddenError()
    notification.read = True
    session.add(notification)
    await session.commit()
    await session.refresh(notification)
    return notification


async def run_daily_reminders(session: AsyncSession) -> int:
    """FR-19.2/FR-8.4/FR-9.5 — chạy hằng ngày, tạo thông báo nhắc trước hạn.

    Số ngày nhắc lấy từ `CompanySettings` (FR-19.2 — cấu hình được).
    """
    from app.services.settings_service import get_company_settings

    settings_row = await get_company_settings(session)
    today = utcnow().date()
    created = 0

    # FR-19.2 — công việc sắp đến hạn.
    task_due = today + timedelta(days=settings_row.task_reminder_days)
    result = await session.exec(select(Task).where(Task.due_date == task_due, Task.status != TaskStatus.DONE, Task.assignee_id.is_not(None)))
    for task in result.all():
        await create_notification(
            session,
            user_id=task.assignee_id,
            title="Sắp đến hạn",
            message=f'Công việc "{task.title}" sẽ đến hạn vào {task_due.strftime("%d/%m/%Y")}',
        )
        created += 1

    # FR-9.5/19.2 — đợt thanh toán hợp đồng sắp đến hạn/quá hạn.
    debt_due = today + timedelta(days=settings_row.debt_reminder_days)
    result = await session.exec(
        select(ContractMilestone, Contract)
        .join(Contract, ContractMilestone.contract_id == Contract.id)
        .where(ContractMilestone.due_date == debt_due, ContractMilestone.status != MilestoneStatus.PAID)
    )
    for milestone, contract in result.all():
        # Thông báo tới người quản lý dự án (manager_id) — đơn giản hoá phạm vi người nhận ở phase này.
        project = await session.get(Project, contract.project_id)
        if project is not None:
            await create_notification(
                session,
                user_id=project.manager_id,
                title="Công nợ sắp đến hạn",
                message=f'Đợt "{milestone.name}" của hợp đồng {contract.code} sắp đến hạn thu',
            )
            created += 1

    # FR-8.4 — nhắc chạy phân bổ chi phí chung vào ngày cấu hình hằng tháng.
    if today.day == settings_row.overhead_reminder_day:
        month = f"{today.year:04d}-{today.month:02d}"
        has_cost = (await session.exec(select(OverheadCost).where(OverheadCost.month == month))).first()
        already_allocated = (await session.exec(select(OverheadAllocation).where(OverheadAllocation.month == month))).first()
        if has_cost and not already_allocated:
            admins_result = await session.exec(select(User).where(User.role.in_(["ADMIN", "DIRECTOR"])))
            for admin in admins_result.all():
                await create_notification(
                    session,
                    user_id=admin.id,
                    title="Nhắc chạy phân bổ chi phí chung",
                    message=f"Chi phí chung tháng {month} chưa được phân bổ vào P&L",
                )
                created += 1

    return created
