"""
Centralized logging configuration for the application.

This module provides a structured logging setup with:
- ISO 8601 timestamp format
- Appropriate log levels (INFO, ERROR, DEBUG)
- Module, function, and line number context
- Stack trace logging for exceptions
"""

import logging
import sys
from datetime import datetime

from app.core.config import LogLevel, settings


class LocalTimeFormatter(logging.Formatter):
    """Custom formatter that uses server's local time in ISO 8601 format."""

    def formatTime(self, record: logging.LogRecord, datefmt: str | None = None) -> str:
        """Format time as ISO 8601 local timestamp with timezone offset."""
        dt = datetime.fromtimestamp(record.created)
        # Get local timezone-aware datetime
        local_dt = dt.astimezone()
        return local_dt.isoformat()

    def format(self, record: logging.LogRecord) -> str:
        """Format log record with custom timestamp."""
        # Add custom attributes if they exist
        if hasattr(record, "user_id"):
            user_id = getattr(record, "user_id", None)
            record.msg = f"[user_id={user_id}] {record.msg}"  # type: ignore
        if hasattr(record, "request_id"):
            request_id = getattr(record, "request_id", None)
            record.msg = f"[request_id={request_id}] {record.msg}"  # type: ignore
        return super().format(record)


# Don't initialize logging on module import - let main.py do it
# This ensures environment variables are loaded first
def setup_logging(log_level: LogLevel | str | None = None) -> None:
    """
    Configure application-wide logging.

    Args:
        log_level: The logging level (LogLevel enum, or string like DEBUG, INFO, WARNING, ERROR, CRITICAL).
                   If None, will be determined from settings.EFFECTIVE_LOG_LEVEL.
    """
    # Determine log level from settings if not provided
    if log_level is None:
        log_level = settings.EFFECTIVE_LOG_LEVEL

    # Convert to string if LogLevel enum
    if isinstance(log_level, LogLevel):
        log_level_str = log_level.value
    else:
        log_level_str = log_level

    # Convert to logging constant
    numeric_level = getattr(logging, log_level_str.upper())

    # Create formatter with ISO 8601 timestamp
    formatter = LocalTimeFormatter(
        fmt="[%(asctime)s] [%(levelname)s] [%(name)s:%(funcName)s:%(lineno)d] %(message)s",
        datefmt=None,
    )

    # Configure root logger - be aggressive about it
    root_logger = logging.getLogger()
    root_logger.setLevel(numeric_level)

    # Remove ALL existing handlers to ensure clean slate
    for handler in root_logger.handlers[:]:
        root_logger.removeHandler(handler)
        handler.close()

    # Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(numeric_level)
    console_handler.setFormatter(formatter)
    root_logger.addHandler(console_handler)

    # Configure third-party loggers
    # Set them to at least WARNING, or higher if user specified higher level
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
        # Remove their handlers too
        for handler in third_party_logger.handlers[:]:
            third_party_logger.removeHandler(handler)
        # Propagate to root logger
        third_party_logger.propagate = True

    # Log the configured level (only if at INFO or lower)
    if numeric_level <= logging.INFO:
        root_logger.info(f"Logging configured with level: {log_level_str}")


def get_logger(name: str) -> logging.Logger:
    """
    Get a logger instance for a module.

    Args:
        name: The name of the module (typically __name__)

    Returns:
        A configured logger instance
    """
    return logging.getLogger(name)


def log_exception(logger: logging.Logger, exc: Exception, context: str = "") -> None:
    """
    Log an exception with full stack trace.

    Args:
        logger: The logger instance to use
        exc: The exception to log
        context: Additional context about where the exception occurred
    """
    if context:
        logger.error(f"{context}: {str(exc)}", exc_info=True, stack_info=True)
    else:
        logger.error(f"Exception occurred: {str(exc)}", exc_info=True, stack_info=True)
