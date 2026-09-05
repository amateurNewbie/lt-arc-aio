from contextlib import asynccontextmanager

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.core.config import get_settings
from app.db.base import metadata  # noqa: F401 — import every model so SQLAlchemy's mapper
# registry is fully populated before the first request; otherwise a fresh process can
# hit `NoReferencedTableError` the first time an ORM flush touches a cross-model FK
# (e.g. User.department_id) whose target model module was never separately imported.
from app.db.session import async_session_factory
from app.services.notification_service import run_daily_reminders

settings = get_settings()


async def _run_daily_reminders_job() -> None:
    async with async_session_factory() as session:
        await run_daily_reminders(session)


@asynccontextmanager
async def lifespan(_app: FastAPI):
    scheduler = AsyncIOScheduler()
    scheduler.add_job(_run_daily_reminders_job, CronTrigger(hour=1, minute=0), id="daily_reminders")
    scheduler.start()
    yield
    scheduler.shutdown(wait=False)


app = FastAPI(title="LT ARC API", version="0.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
