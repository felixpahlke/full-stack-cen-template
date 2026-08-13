"""
Centralized logging configuration for the application.

This module provides a structured logging setup with:
- UTC ISO 8601 timestamps
- Environment-driven log levels
- Module, function, and line number context
"""

import logging
import sys
from datetime import datetime, timezone

from app.core.config import LogLevel, get_settings


class UTCFormatter(logging.Formatter):
    """Format log records with UTC ISO 8601 timestamps."""

    def formatTime(self, record: logging.LogRecord, datefmt: str | None = None) -> str:
        return datetime.fromtimestamp(record.created, timezone.utc).isoformat()


def setup_logging(log_level: LogLevel | str | None = None) -> None:
    """
    Configure application-wide logging.

    Args:
        log_level: The logging level (LogLevel enum, or string like DEBUG, INFO, WARNING,
            ERROR, CRITICAL). If omitted, uses the environment-derived effective level.
    """
    if log_level is None:
        log_level = get_settings().EFFECTIVE_LOG_LEVEL

    if isinstance(log_level, LogLevel):
        log_level_str = log_level.value
    else:
        log_level_str = log_level

    numeric_level = getattr(logging, log_level_str.upper(), logging.INFO)

    formatter = UTCFormatter(
        fmt="[%(asctime)s] [%(levelname)s] [%(name)s:%(funcName)s:%(lineno)d] %(message)s",
        datefmt=None,
    )

    root_logger = logging.getLogger()
    root_logger.setLevel(numeric_level)

    for handler in root_logger.handlers[:]:
        root_logger.removeHandler(handler)
        handler.close()

    console_handler = logging.StreamHandler(sys.stderr)
    console_handler.setLevel(numeric_level)
    console_handler.setFormatter(formatter)
    root_logger.addHandler(console_handler)

    third_party_level = max(numeric_level, logging.WARNING)
    for logger_name in [
        "uvicorn",
        "uvicorn.access",
        "uvicorn.error",
    ]:
        third_party_logger = logging.getLogger(logger_name)
        third_party_logger.setLevel(third_party_level)
        for handler in third_party_logger.handlers[:]:
            third_party_logger.removeHandler(handler)
        third_party_logger.propagate = True

    if numeric_level <= logging.INFO:
        root_logger.info("Logging configured with level: %s", log_level_str.upper())


def get_logger(name: str) -> logging.Logger:
    """
    Get a logger instance for a module.

    Args:
        name: The name of the module (typically __name__)

    Returns:
        A configured logger instance
    """
    return logging.getLogger(name)
