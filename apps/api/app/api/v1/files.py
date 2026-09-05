from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, UploadFile, status
from fastapi.responses import Response
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.config import get_settings
from app.core.deps import get_current_user, get_session
from app.models.file_asset import FileAsset
from app.models.user import User
from app.schemas.file_asset import FileAssetRead
from app.services.file_service import delete_file, list_by_project, read_file, save_file

router = APIRouter(prefix="/api/files", tags=["files"])
settings = get_settings()


@router.get("", response_model=list[FileAssetRead])
async def list_files_endpoint(
    project_id: UUID,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(get_current_user),
) -> list[FileAsset]:
    """FR-17.2 — xem danh sách tệp theo dự án."""
    return await list_by_project(session, project_id)


@router.post("", response_model=FileAssetRead, status_code=status.HTTP_201_CREATED)
async def upload_file_endpoint(
    project_id: UUID,
    file: UploadFile,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
) -> FileAsset:
    """FR-17.1 — tải lên tệp gắn với một dự án, giới hạn dung lượng."""
    content = await file.read()
    if len(content) > settings.max_file_size_bytes:
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, "File exceeds max size")

    return await save_file(
        session,
        project_id=project_id,
        filename=file.filename or "unnamed",
        content_type=file.content_type or "application/octet-stream",
        content=content,
        uploaded_by_id=user.id,
    )


@router.get("/{file_id}/download")
async def download_file_endpoint(
    file_id: UUID,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(get_current_user),
) -> Response:
    asset = await session.get(FileAsset, file_id)
    if asset is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "File not found")
    content = read_file(asset)
    return Response(
        content=content,
        media_type=asset.type,
        headers={"Content-Disposition": f'attachment; filename="{asset.name}"'},
    )


@router.delete("/{file_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_file_endpoint(
    file_id: UUID,
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(get_current_user),
) -> None:
    """FR-17.3 — xoá tệp đính kèm."""
    asset = await session.get(FileAsset, file_id)
    if asset is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "File not found")
    await delete_file(session, asset)
