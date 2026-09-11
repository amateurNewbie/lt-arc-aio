"""Wrapper mỏng quanh Firebase Admin SDK để gửi push notification (FCM).

Khởi tạo lazy + singleton vì `firebase_admin.initialize_app()` chỉ được gọi
một lần cho toàn bộ process. Nếu chưa cấu hình `FCM_SERVICE_ACCOUNT_JSON_BASE64`
(local/test), `send_push` tự bỏ qua thay vì raise — gửi push là "best effort",
không được phép làm hỏng luồng tạo `Notification` trong DB.
"""

import base64
import json
import logging

import firebase_admin
from firebase_admin import credentials, exceptions, messaging

from app.core.config import get_settings

logger = logging.getLogger(__name__)

_app: firebase_admin.App | None = None
_init_attempted = False


def _get_app() -> firebase_admin.App | None:
    global _app, _init_attempted
    if _init_attempted:
        return _app
    _init_attempted = True

    settings = get_settings()
    if not settings.fcm_service_account_json_base64:
        logger.warning("FCM chưa được cấu hình (FCM_SERVICE_ACCOUNT_JSON_BASE64 rỗng) — bỏ qua gửi push")
        return None

    try:
        raw = base64.b64decode(settings.fcm_service_account_json_base64)
        service_account_info = json.loads(raw)
        cred = credentials.Certificate(service_account_info)
        _app = firebase_admin.initialize_app(cred)
    except Exception:
        logger.exception("Không khởi tạo được Firebase Admin SDK — kiểm tra lại FCM_SERVICE_ACCOUNT_JSON_BASE64")
        _app = None
    return _app


def send_push(*, tokens: list[str], title: str, message: str, data: dict[str, str]) -> list[str]:
    """Gửi push tới danh sách token, trả về các token không còn hợp lệ (nên xoá khỏi DB)."""
    if not tokens:
        return []

    app = _get_app()
    if app is None:
        return []

    invalid_tokens: list[str] = []
    for token in tokens:
        fcm_message = messaging.Message(
            notification=messaging.Notification(title=title, body=message),
            data=data,
            token=token,
        )
        try:
            messaging.send(fcm_message, app=app)
        except (exceptions.NotFoundError, exceptions.InvalidArgumentError):
            invalid_tokens.append(token)
        except exceptions.FirebaseError:
            logger.exception("Gửi FCM thất bại cho 1 token (giữ lại, có thể là lỗi tạm thời)")
    return invalid_tokens
