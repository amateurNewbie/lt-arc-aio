"""Seed data tối thiểu — chạy: `uv run python scripts/seed.py` (xem plan §9)."""

import asyncio

from sqlmodel import select

from app.core.permissions import Role
from app.db.base import metadata  # noqa: F401 — registers every table model before any ORM flush
from app.db.session import async_session_factory
from app.models.company_settings import CompanySettings
from app.models.cost_category import CostCategory
from app.models.enums import CostCategoryScope
from app.models.user import User
from app.services.auth_service import create_user

DEFAULT_PROJECT_CATEGORIES = [
    "Vật tư",
    "Nhân công",
    "Máy móc thiết bị",
    "Thầu phụ",
    "Quản lý chung",
    "Khác",
]
DEFAULT_COMPANY_CATEGORIES = [
    "Thuê văn phòng",
    "Lương hành chính/kế toán",
    "Marketing",
    "Khấu hao thiết bị",
    "Điện nước văn phòng",
    "Khác",
]


async def seed() -> None:
    async with async_session_factory() as session:
        existing_settings = (await session.exec(select(CompanySettings))).first()
        if existing_settings is None:
            session.add(CompanySettings(name="LT ARC Studio", currency="VND", unit="m2"))

        for name in DEFAULT_PROJECT_CATEGORIES:
            result = await session.exec(select(CostCategory).where(CostCategory.name == name))
            if result.first() is None:
                session.add(CostCategory(name=name, scope=CostCategoryScope.PROJECT))

        for name in DEFAULT_COMPANY_CATEGORIES:
            result = await session.exec(select(CostCategory).where(CostCategory.name == name))
            if result.first() is None:
                session.add(CostCategory(name=name, scope=CostCategoryScope.COMPANY))

        await session.commit()

        any_user = (await session.exec(select(User).limit(1))).first()
        if any_user is None:
            await create_user(session, email="admin@ltarc.vn", password="ChangeMe123!", role=Role.ADMIN)
            await create_user(session, email="director@ltarc.vn", password="ChangeMe123!", role=Role.DIRECTOR)
            print("Seeded: admin@ltarc.vn / director@ltarc.vn (password: ChangeMe123!)")
        else:
            print("Users already exist — skipped user seeding.")

    print("Seed done.")


if __name__ == "__main__":
    asyncio.run(seed())
