from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.deps import get_current_user, get_session
from app.core.security import create_access_token, create_refresh_token
from app.models.user import User
from app.schemas.auth import LoginRequest, MeResponse, TokenResponse
from app.services.auth_service import AccountLockedError, InvalidCredentialsError, authenticate

router = APIRouter(prefix="/api/auth", tags=["auth"])


@router.post("/login", response_model=TokenResponse)
async def login(payload: LoginRequest, session: AsyncSession = Depends(get_session)) -> TokenResponse:
    try:
        user = await authenticate(session, payload.email, payload.password)
    except InvalidCredentialsError as exc:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid email or password") from exc
    except AccountLockedError as exc:
        raise HTTPException(
            status.HTTP_423_LOCKED,
            f"Account locked until {exc.locked_until.isoformat()}",
        ) from exc

    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


@router.get("/me", response_model=MeResponse)
async def me(user: User = Depends(get_current_user)) -> MeResponse:
    return MeResponse(id=user.id, email=user.email, role=user.role, department_id=user.department_id)
