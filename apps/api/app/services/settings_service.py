from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.models.company_settings import CompanySettings


async def get_company_settings(session: AsyncSession) -> CompanySettings:
    """FR-20.1 — bản ghi duy nhất; tự tạo mặc định nếu seed chưa chạy."""
    result = await session.exec(select(CompanySettings))
    settings_row = result.first()
    if settings_row is None:
        settings_row = CompanySettings(name="LT ARC Studio")
        session.add(settings_row)
        await session.commit()
        await session.refresh(settings_row)
    return settings_row


async def update_company_settings(session: AsyncSession, updates: dict) -> CompanySettings:
    """FR-20.2 — chỉ ADMIN/Giám đốc sửa (kiểm tra ở router)."""
    settings_row = await get_company_settings(session)
    for key, value in updates.items():
        if value is not None:
            setattr(settings_row, key, value)
    session.add(settings_row)
    await session.commit()
    await session.refresh(settings_row)
    return settings_row


def security_status() -> list[dict]:
    """FR-20.4 — minh bạch hoá các biện pháp bảo mật đang áp dụng."""
    return [
        {"name": "Mã hoá mật khẩu (bcrypt) & bắt buộc HTTPS", "active": True},
        {"name": "Khoá tài khoản sau 5 lần đăng nhập sai", "active": True},
        {"name": "Giới hạn xem phiếu lương (chỉ Admin/Giám đốc/chính chủ)", "active": True},
        {"name": "Khoá số công sau khi lương đã trả", "active": True},
        {"name": "Nhật ký hoạt động (không sửa/xoá âm thầm)", "active": True},
        {"name": "Tự đăng xuất phiên không hoạt động sau 24 giờ", "active": False},
    ]
