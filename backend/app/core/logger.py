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
from datetime import datetime, timezone


class UTCFormatter(logging.Formatter):
    """Custom formatter that uses UTC time in ISO 8601 format."""

    def formatTime(self, record: logging.LogRecord, datefmt: str | None = None) -> str:
        """Format time as ISO 8601 UTC timestamp."""
        dt = datetime.fromtimestamp(record.created, tz=timezone.utc)
        return dt.isoformat()

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


def get_log_level_from_environment() -> str:
    """
    Determine log level based on LOG_LEVEL or ENVIRONMENT variable.

    Priority:
    1. LOG_LEVEL environment variable (if set, overrides everything)
    2. ENVIRONMENT-based defaults (local=DEBUG, staging=INFO, production=WARNING)

    Returns:
        Log level string (DEBUG, INFO, WARNING, ERROR, CRITICAL)
    """
    import os

    # Check for explicit LOG_LEVEL override first
    explicit_log_level = os.getenv("LOG_LEVEL")
    if explicit_log_level:
        return explicit_log_level.upper()

    # Fall back to environment-based defaults
    environment = os.getenv("ENVIRONMENT", "local").lower()

    if environment == "local":
        return "DEBUG"  # Verbose logging for development
    elif environment == "staging":
        return "INFO"  # Standard logging for staging
    elif environment == "production":
        return "WARNING"  # Only warnings and errors for production
    else:
        return "INFO"  # Default to INFO


def setup_logging(log_level: str | None = None) -> None:
    """
    Configure application-wide logging.

    Args:
        log_level: The logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL).
                   If None, will be determined from LOG_LEVEL or ENVIRONMENT variable.
    """
    # Determine log level from environment if not provided
    if log_level is None:
        log_level = get_log_level_from_environment()

    # Convert to logging constant
    numeric_level = getattr(logging, log_level.upper())

    # Create formatter with ISO 8601 timestamp
    formatter = UTCFormatter(
        fmt="[%(asctime)s] [%(levelname)s] [%(name)s:%(funcName)s:%(lineno)d] %(message)s",
        datefmt=None,  # Will use formatTime method
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
        root_logger.info(f"Logging configured with level: {log_level}")


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


# Don't initialize logging on module import - let main.py do it
# This ensures environment variables are loaded first

