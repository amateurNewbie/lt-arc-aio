from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    env: str = "development"
    database_url: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/lt_arc"
    jwt_secret: str = "change-me"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 14
    cors_origins: str = "http://localhost:5173,http://localhost:8010,http://127.0.0.1:5173,http://127.0.0.1:8010"
    file_root: str = "./var/files"
    max_file_size_bytes: int = 20 * 1024 * 1024  # FR-17.1 — giới hạn 20MB/tệp

    failed_login_lockout_threshold: int = 5
    failed_login_lockout_minutes: int = 15
    idle_logout_hours: int = 24

    @property
    def cors_origin_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
