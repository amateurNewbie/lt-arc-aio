"""Seed data tối thiểu — chạy: `uv run python scripts/seed.py` (xem plan §9)."""

import asyncio
import sys
from datetime import datetime

from sqlmodel import select

from app.core.permissions import Role
from app.db.base import metadata  # noqa: F401 — registers every table model before any ORM flush
from app.db.session import async_session_factory
from app.models.company_settings import CompanySettings
from app.models.cost_category import CostCategory
from app.models.enums import CostCategoryScope, LeadStatus, ProjectCategory, ProjectStatus
from app.models.lead import Lead
from app.models.project import Project
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
            admin = await create_user(
                session, email="admin@ltarc.vn", password="ChangeMe123!", role=Role.ADMIN, full_name="Trần Minh Khoa"
            )
            director = await create_user(
                session, email="director@ltarc.vn", password="ChangeMe123!", role=Role.DIRECTOR, full_name="Nguyễn Thị Lan"
            )
            print("Seeded: admin@ltarc.vn / director@ltarc.vn (password: ChangeMe123!)")
        else:
            print("Users already exist — skipped user seeding.")
            admin = (await session.exec(select(User).where(User.email == "admin@ltarc.vn"))).first()
            director = (await session.exec(select(User).where(User.email == "director@ltarc.vn"))).first()

        any_lead = (await session.exec(select(Lead).limit(1))).first()
        if any_lead is None and admin is not None and director is not None:
            demo_project = Project(
                code="LT-2604-03",
                name="Căn hộ Vinhomes Ocean Park",
                client="Anh Quang Huy",
                category=ProjectCategory.DESIGN,
                type="Căn hộ chung cư cải tạo",
                budget=450_000_000,
                progress=100,
                status=ProjectStatus.COMPLETED,
                manager_id=director.id,
            )
            session.add(demo_project)
            await session.flush()

            def _on(day: int, month: int) -> datetime:
                """Naive UTC — khớp cột `TIMESTAMP WITHOUT TIME ZONE` (xem app.core.clock.utcnow)."""
                return datetime(2026, month, day, 9, 0)

            leads = [
                Lead(
                    name="Anh Đình Phong",
                    phone="0966 777 888",
                    need="Nhà xưởng nhỏ",
                    budget_estimate=5_000_000_000,
                    source="Khác",
                    owner_id=director.id,
                    status=LeadStatus.CONSULTING,
                    created_at=_on(28, 8),
                ),
                Lead(
                    name="Anh Hoàng Minh",
                    phone="0911 222 333",
                    need="Nhà phố 4 tầng",
                    budget_estimate=1_200_000_000,
                    source="Giới thiệu",
                    owner_id=director.id,
                    status=LeadStatus.NEW,
                    created_at=_on(30, 8),
                ),
                Lead(
                    name="Chị Thu Hà",
                    phone="0922 333 444",
                    need="Biệt thự sân vườn",
                    budget_estimate=3_500_000_000,
                    source="Website",
                    owner_id=director.id,
                    status=LeadStatus.CONSULTING,
                    created_at=_on(25, 8),
                ),
                Lead(
                    name="Cty TNHH Phát Đạt",
                    phone="0933 444 555",
                    need="Văn phòng cho thuê 500m²",
                    budget_estimate=2_800_000_000,
                    source="Mạng xã hội",
                    owner_id=admin.id,
                    status=LeadStatus.QUOTED,
                    created_at=_on(20, 8),
                ),
                Lead(
                    name="Anh Quang Huy",
                    phone="0944 555 666",
                    need="Căn hộ chung cư cải tạo",
                    budget_estimate=450_000_000,
                    source="Giới thiệu",
                    owner_id=director.id,
                    status=LeadStatus.CONVERTED,
                    converted_project_id=demo_project.id,
                    created_at=_on(10, 8),
                ),
                Lead(
                    name="Chị Kim Ngân",
                    phone="0955 666 777",
                    need="Showroom nội thất",
                    budget_estimate=1_800_000_000,
                    source="Website",
                    owner_id=admin.id,
                    status=LeadStatus.REJECTED,
                    created_at=_on(5, 8),
                ),
            ]
            for lead in leads:
                session.add(lead)
            await session.commit()
            print(f"Seeded: 1 dự án demo (LT-2604-03) + {len(leads)} khách hàng tiềm năng.")
        else:
            print("Leads already exist — skipped lead seeding.")

    print("Seed done.")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")  # console Windows mặc định cp1252, vỡ khi print tiếng Việt
    asyncio.run(seed())
