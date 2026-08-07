import secrets
import warnings
from enum import Enum
from functools import lru_cache
from pathlib import Path
from typing import Annotated, Any, Literal

from pydantic import (
    AnyUrl,
    BeforeValidator,
    PostgresDsn,
    computed_field,
    model_validator,
)
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing_extensions import Self

BACKEND_ROOT = Path(__file__).resolve().parents[2]
REPO_ROOT = BACKEND_ROOT.parent if BACKEND_ROOT.name == "backend" else BACKEND_ROOT
ENV_FILE = REPO_ROOT / ".env"
API_V1_STR = "/api/v1"


class Environment(str, Enum):
    LOCAL = "local"
    STAGING = "staging"
    PRODUCTION = "production"


class LogLevel(str, Enum):
    DEBUG = "DEBUG"
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"
    CRITICAL = "CRITICAL"


def parse_cors(v: Any) -> list[str] | str:
    if isinstance(v, str) and not v.startswith("["):
        return [i.strip() for i in v.split(",")]
    elif isinstance(v, list | str):
        return v
    raise ValueError(v)


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=ENV_FILE,
        env_ignore_empty=True,
        extra="ignore",
    )
    API_V1_STR: str = API_V1_STR
    SECRET_KEY: str = secrets.token_urlsafe(32)
    # 60 minutes * 24 hours * 8 days = 8 days
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 8
    FRONTEND_HOST: str = "http://localhost:5173"
    ENVIRONMENT: Environment = Environment.LOCAL
    LOG_LEVEL: LogLevel | None = None  # Optional override for log level
    MIGRATE_ON_START: bool = True
    MIGRATION_LOCK_TIMEOUT_SECONDS: float = 60

    @computed_field  # type: ignore[prop-decorator]
    @property
    def EFFECTIVE_LOG_LEVEL(self) -> LogLevel:
        if self.LOG_LEVEL is not None:
            return self.LOG_LEVEL

        if self.ENVIRONMENT == Environment.LOCAL:
            return LogLevel.INFO  # Standard logging for local development
        elif self.ENVIRONMENT == Environment.STAGING:
            return LogLevel.INFO  # Standard logging for staging
        elif self.ENVIRONMENT == Environment.PRODUCTION:
            return LogLevel.WARNING  # Only warnings and errors for production
        else:
            return LogLevel.INFO  # Default to INFO

    BACKEND_CORS_ORIGINS: Annotated[
        list[AnyUrl | Literal["*"]] | str, BeforeValidator(parse_cors)
    ] = []

    @computed_field  # type: ignore[prop-decorator]
    @property
    def all_cors_origins(self) -> list[str]:
        return [str(origin).rstrip("/") for origin in self.BACKEND_CORS_ORIGINS] + [
            self.FRONTEND_HOST
        ]

    PROJECT_NAME: str
    POSTGRES_SERVER: str
    POSTGRES_PORT: int = 5432
    POSTGRES_USER: str
    POSTGRES_PASSWORD: str = ""
    POSTGRES_DB: str = ""

    @computed_field  # type: ignore[prop-decorator]
    @property
    def SQLALCHEMY_DATABASE_URI(self) -> PostgresDsn:
        return PostgresDsn.build(
            scheme="postgresql+psycopg",
            username=self.POSTGRES_USER,
            password=self.POSTGRES_PASSWORD,
            host=self.POSTGRES_SERVER,
            port=self.POSTGRES_PORT,
            path=self.POSTGRES_DB,
        )

    # TODO: update type to EmailStr when sqlmodel supports it
    EMAIL_TEST_USER: str = "test@example.com"
    # TODO: update type to EmailStr when sqlmodel supports it
    FIRST_SUPERUSER: str
    FIRST_SUPERUSER_PASSWORD: str
    SIGNUP_ACCESS_PASSWORD: str = ""

    def _check_default_secret(self, var_name: str, value: str | None) -> None:
        if value == "changethis":
            message = (
                f'The value of {var_name} is "changethis", '
                "for security, please change it, at least for deployments."
            )
            if self.ENVIRONMENT == "local":
                warnings.warn(message, stacklevel=1)
            else:
                raise ValueError(message)

    @model_validator(mode="after")
    def _enforce_non_default_secrets(self) -> Self:
        self._check_default_secret("SECRET_KEY", self.SECRET_KEY)
        self._check_default_secret("POSTGRES_PASSWORD", self.POSTGRES_PASSWORD)
        self._check_default_secret(
            "FIRST_SUPERUSER_PASSWORD", self.FIRST_SUPERUSER_PASSWORD
        )

        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()  # type: ignore[call-arg]
