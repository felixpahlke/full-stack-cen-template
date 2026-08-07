from enum import Enum
from functools import lru_cache
from pathlib import Path
from typing import Annotated, Any, Literal

from pydantic import (
    AnyUrl,
    BeforeValidator,
    computed_field,
)
from pydantic_settings import BaseSettings, SettingsConfigDict

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
    API_KEY: str
    TELEMETRY_ENABLED: bool = False
    ENVIRONMENT: Environment = Environment.LOCAL
    LOG_LEVEL: LogLevel | None = None  # Optional override for log level

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
        if self.BACKEND_CORS_ORIGINS == "*":
            return ["*"]
        return [str(origin).rstrip("/") for origin in self.BACKEND_CORS_ORIGINS]

    PROJECT_NAME: str


@lru_cache
def get_settings() -> Settings:
    return Settings()  # type: ignore[call-arg]
