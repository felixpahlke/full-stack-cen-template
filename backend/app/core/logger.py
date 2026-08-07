import logging
import sys
from datetime import datetime, timezone

from app.core.config import LogLevel, get_settings


class UTCFormatter(logging.Formatter):
    def formatTime(self, record: logging.LogRecord, datefmt: str | None = None) -> str:
        return datetime.fromtimestamp(record.created, timezone.utc).isoformat()


def setup_logging(log_level: LogLevel | str | None = None) -> None:
    if log_level is None:
        log_level = get_settings().EFFECTIVE_LOG_LEVEL
    log_level_str = log_level.value if isinstance(log_level, LogLevel) else log_level
    numeric_level = getattr(logging, log_level_str.upper(), logging.INFO)
    formatter = UTCFormatter(
        fmt="[%(asctime)s] [%(levelname)s] [%(name)s:%(funcName)s:%(lineno)d] %(message)s"
    )
    root_logger = logging.getLogger()
    root_logger.setLevel(numeric_level)
    for handler in root_logger.handlers[:]:
        root_logger.removeHandler(handler)
        handler.close()
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(numeric_level)
    console_handler.setFormatter(formatter)
    root_logger.addHandler(console_handler)
    third_party_level = max(numeric_level, logging.WARNING)
    for logger_name in [
        "uvicorn",
        "uvicorn.access",
        "uvicorn.error",
        "sqlalchemy",
        "sqlalchemy.engine",
    ]:
        third_party_logger = logging.getLogger(logger_name)
        third_party_logger.setLevel(third_party_level)
        for handler in third_party_logger.handlers[:]:
            third_party_logger.removeHandler(handler)
        third_party_logger.propagate = True


def get_logger(name: str) -> logging.Logger:
    return logging.getLogger(name)
