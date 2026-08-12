import warnings
from enum import Enum
from functools import lru_cache
from pathlib import Path
from typing import TYPE_CHECKING, Annotated, Any, Literal

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

UPSTREAM_PASSWORD_PLACEHOLDER = "changethis"
COOKIE_SECRET_PLACEHOLDER = "changethis"
CLIENT_SECRET_PLACEHOLDER = "changethis"
PUBLIC_SECRET_VALUES = {
    "",
    "changethis",
    "changeme",
    "generate-on-first-dev-run",
    "replace-me",
    "secret",
}


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


def parse_cors(value: Any) -> list[str] | str:
    if isinstance(value, str) and not value.startswith("["):
        return [item.strip() for item in value.split(",") if item.strip()]
    if isinstance(value, list | str):
        return value
    raise ValueError(value)


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=ENV_FILE,
        env_ignore_empty=True,
        extra="ignore",
    )

    API_V1_STR: str = API_V1_STR
    CEN_FLAVOR: str = "oauth-proxy-custom-ui"
    PROJECT_NAME: str
    ENVIRONMENT: Environment = Environment.LOCAL
    LOG_LEVEL: LogLevel | None = None
    MIGRATE_ON_START: bool = True
    MIGRATION_LOCK_TIMEOUT_SECONDS: float = 60

    API_PORT: int = 8000
    WEB_PORT: int = 5173
    DB_PORT: int = 5432
    ADMINER_PORT: int = 8080
    DEX_PORT: int = 5556
    OAUTH2_PROXY_PORT: int = 4180

    OAUTH2_PROXY_UPSTREAM_PASSWORD: str = UPSTREAM_PASSWORD_PLACEHOLDER
    OAUTH2_PROXY_COOKIE_SECRET: str = COOKIE_SECRET_PLACEHOLDER
    OAUTH2_PROXY_CLIENT_SECRET: str = CLIENT_SECRET_PLACEHOLDER

    BACKEND_CORS_ORIGINS: Annotated[
        list[AnyUrl | Literal["*"]] | str, BeforeValidator(parse_cors)
    ] = []

    POSTGRES_SERVER: str
    POSTGRES_PORT: int = 5432
    POSTGRES_USER: str
    POSTGRES_PASSWORD: str = ""
    POSTGRES_DB: str = ""

    @computed_field  # type: ignore[prop-decorator]
    @property
    def EFFECTIVE_LOG_LEVEL(self) -> LogLevel:
        if self.LOG_LEVEL is not None:
            return self.LOG_LEVEL
        if self.ENVIRONMENT == Environment.PRODUCTION:
            return LogLevel.WARNING
        return LogLevel.INFO

    @computed_field  # type: ignore[prop-decorator]
    @property
    def all_cors_origins(self) -> list[str]:
        return [str(origin).rstrip("/") for origin in self.BACKEND_CORS_ORIGINS]

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

    def _check_secret(
        self,
        var_name: str,
        value: str,
        *,
        minimum_length: int = 32,
    ) -> None:
        normalized = value.strip()
        weak = (
            normalized.lower() in PUBLIC_SECRET_VALUES
            or (normalized.startswith("<") and normalized.endswith(">"))
            or len(normalized) < minimum_length
            or len(set(normalized)) == 1
        )
        if not weak:
            return
        message = (
            f"{var_name} must be a non-placeholder random value of at least "
            f"{minimum_length} characters. Run `pnpm run dev` to generate local values."
        )
        raise ValueError(message)

    @model_validator(mode="after")
    def _enforce_non_default_secrets(self) -> Self:
        if self.POSTGRES_PASSWORD == "changethis":
            message = "POSTGRES_PASSWORD must be changed for deployments."
            if self.ENVIRONMENT == Environment.LOCAL:
                warnings.warn(message, stacklevel=1)
            else:
                raise ValueError(message)
        self._check_secret(
            "OAUTH2_PROXY_UPSTREAM_PASSWORD",
            self.OAUTH2_PROXY_UPSTREAM_PASSWORD,
        )
        self._check_secret(
            "OAUTH2_PROXY_COOKIE_SECRET", self.OAUTH2_PROXY_COOKIE_SECRET
        )
        self._check_secret(
            "OAUTH2_PROXY_CLIENT_SECRET", self.OAUTH2_PROXY_CLIENT_SECRET
        )
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()  # type: ignore[call-arg]


if TYPE_CHECKING:
    settings: Settings


def __getattr__(name: str) -> Settings:
    """Keep the historical settings import lazy and factory-backed."""
    if name == "settings":
        return get_settings()
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
