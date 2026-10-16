from functools import lru_cache
from pathlib import Path
from pydantic import Field, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file='.env', env_file_encoding='utf-8', case_sensitive=False, extra='ignore')
    app_name: str = 'sipe-sipe-gestion-api'
    app_version: str = '0.1.0'
    app_env: str = 'development'
    database_url: str = ''
    postgres_db: str = 'gestion_sipe'
    postgres_user: str = 'sipe_app'
    postgres_password: str = ''
    postgres_host: str = 'localhost'
    postgres_port: int = 5432
    jwt_access_secret: str = ''
    jwt_issuer: str = 'sipe-sipe-gestion-api'
    jwt_audience: str = 'sipe-sipe-gestion-admin'
    access_token_ttl_minutes: int = 15
    refresh_token_ttl_days: int = 7
    cookie_name: str = 'gestion_refresh_token'
    cookie_path: str = '/api/admin/auth'
    cookie_secure: bool | None = None
    cookie_samesite: str = 'lax'
    cors_allow_origins: str = ''
    cors_allow_credentials: bool = True
    storage_root: Path = Path('storage')
    max_pdf_size_mb: int = 25
    max_image_size_mb: int = 8
    public_base_url: str = 'http://localhost:8001'

    @property
    def effective_database_url(self) -> str:
        if self.database_url:
            return self.database_url
        return f'postgresql+psycopg://{self.postgres_user}:{self.postgres_password}@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}'

    @property
    def cors_origins_list(self) -> list[str]:
        return [item.strip() for item in self.cors_allow_origins.split(',') if item.strip()]

    @property
    def max_pdf_size_bytes(self) -> int:
        return self.max_pdf_size_mb * 1024 * 1024

    @property
    def max_image_size_bytes(self) -> int:
        return self.max_image_size_mb * 1024 * 1024

    @field_validator('cookie_secure', mode='before')
    @classmethod
    def empty_cookie_secure(cls, value):
        return None if value == '' else value

    @field_validator('cookie_samesite')
    @classmethod
    def valid_samesite(cls, value: str) -> str:
        value = value.strip().lower()
        if value not in {'lax', 'strict', 'none'}:
            raise ValueError('COOKIE_SAMESITE debe ser lax, strict o none')
        return value

    @model_validator(mode='after')
    def validate_settings(self):
        self.app_env = self.app_env.strip().lower()
        if self.app_env not in {'development', 'qa', 'production'}:
            raise ValueError('APP_ENV debe ser development, qa o production')
        if not self.jwt_access_secret or len(self.jwt_access_secret) < 32:
            raise ValueError('JWT_ACCESS_SECRET debe tener al menos 32 caracteres')
        if self.cookie_secure is None:
            self.cookie_secure = self.app_env == 'production'
        if self.app_env == 'production' and not self.cookie_secure:
            raise ValueError('Producción requiere COOKIE_SECURE=true')
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
