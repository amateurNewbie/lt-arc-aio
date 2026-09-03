"""Test fixtures — dùng SQLite in-memory thay cho Postgres/Docker (không có sẵn
trên máy dev hiện tại). Production/staging vẫn luôn chạy trên PostgreSQL thật;
xem ghi chú trong `IMPLEMENTATION-PLAN-v2.md` §10."""

from collections.abc import AsyncGenerator

import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.deps import get_session
from app.db.base import metadata
from app.main import app


@pytest_asyncio.fixture
async def session() -> AsyncGenerator[AsyncSession, None]:
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    async with engine.begin() as conn:
        await conn.run_sync(metadata.create_all)

    session_factory = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)
    async with session_factory() as s:
        yield s

    await engine.dispose()


@pytest_asyncio.fixture
async def client(session: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    async def _get_session_override() -> AsyncGenerator[AsyncSession, None]:
        yield session

    app.dependency_overrides[get_session] = _get_session_override
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
    app.dependency_overrides.clear()
