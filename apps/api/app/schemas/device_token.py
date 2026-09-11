from datetime import datetime
from uuid import UUID

from sqlmodel import SQLModel

from app.models.enums import DevicePlatform


class DeviceTokenRegister(SQLModel):
    fcm_token: str
    platform: DevicePlatform


class DeviceTokenRead(SQLModel):
    id: UUID
    platform: DevicePlatform
    created_at: datetime
    last_seen_at: datetime
