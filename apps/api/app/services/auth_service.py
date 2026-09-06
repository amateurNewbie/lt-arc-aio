from datetime import datetime, timedelta

from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.clock import utcnow
from app.core.config import get_settings
from app.core.security import hash_password, verify_password
from app.models.user import User

settings = get_settings()


class InvalidCredentialsError(Exception):
    pass


class AccountLockedError(Exception):
    def __init__(self, locked_until: datetime):
        self.locked_until = locked_until
        super().__init__(f"Account locked until {locked_until.isoformat()}")


async def authenticate(session: AsyncSession, email: str, password: str) -> User:
    """FR-1.1/1.4 — xác thực email/mật khẩu, khoá sau N lần sai liên tiếp."""
    result = await session.exec(select(User).where(User.email == email))
    user = result.first()

    if user is None:
        raise InvalidCredentialsError()

    now = utcnow()
    if user.locked_until is not None and user.locked_until > now:
        raise AccountLockedError(user.locked_until)

    if not verify_password(password, user.password_hash):
        user.failed_login_count += 1
        if user.failed_login_count >= settings.failed_login_lockout_threshold:
            user.locked_until = now + timedelta(minutes=settings.failed_login_lockout_minutes)
        session.add(user)
        await session.commit()
        raise InvalidCredentialsError()

    user.failed_login_count = 0
    user.locked_until = None
    user.last_active_at = now
    session.add(user)
    await session.commit()
    await session.refresh(user)
    return user


async def unlock_user(session: AsyncSession, user: User) -> User:
    """ADMIN mở khoá sớm (FR-1.4)."""
    user.failed_login_count = 0
    user.locked_until = None
    session.add(user)
    await session.commit()
    await session.refresh(user)
    return user


async def create_user(
    session: AsyncSession,
    *,
    email: str,
    password: str,
    role,
    full_name: str | None = None,
    department_id=None,
) -> User:
    """FR-1.3 — chỉ ADMIN/Giám đốc tạo tài khoản (kiểm tra ở router qua require_roles)."""
    user = User(
        email=email,
        password_hash=hash_password(password),
        role=role,
        full_name=full_name,
        department_id=department_id,
    )
    session.add(user)
    await session.commit()
    await session.refresh(user)
    return user
