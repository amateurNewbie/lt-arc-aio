from pathlib import Path
from uuid import UUID, uuid4

from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.config import get_settings
from app.models.file_asset import FileAsset

settings = get_settings()


def _storage_root() -> Path:
    root = Path(settings.file_root)
    root.mkdir(parents=True, exist_ok=True)
    return root


async def save_file(
    session: AsyncSession,
    *,
    project_id: UUID,
    filename: str,
    content_type: str,
    content: bytes,
    uploaded_by_id: UUID,
) -> FileAsset:
    """FR-17.1 — tải lên tệp gắn với một dự án."""
    storage_key = f"{project_id}/{uuid4().hex}_{filename}"
    path = _storage_root() / storage_key
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)

    asset = FileAsset(
        project_id=project_id,
        name=filename,
        type=content_type,
        size_bytes=len(content),
        storage_key=storage_key,
        uploaded_by_id=uploaded_by_id,
    )
    session.add(asset)
    await session.commit()
    await session.refresh(asset)
    return asset


async def list_by_project(session: AsyncSession, project_id: UUID) -> list[FileAsset]:
    result = await session.exec(select(FileAsset).where(FileAsset.project_id == project_id))
    return list(result.all())


def read_file(asset: FileAsset) -> bytes:
    return (_storage_root() / asset.storage_key).read_bytes()


async def delete_file(session: AsyncSession, asset: FileAsset) -> None:
    """FR-17.3 — xoá cả bản ghi metadata lẫn tệp vật lý."""
    path = _storage_root() / asset.storage_key
    path.unlink(missing_ok=True)
    await session.delete(asset)
    await session.commit()
