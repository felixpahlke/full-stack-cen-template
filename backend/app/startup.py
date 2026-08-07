import logging
import os
import time
from pathlib import Path

from alembic import command
from alembic.config import Config
from alembic.migration import MigrationContext
from alembic.script import ScriptDirectory
from sqlalchemy import Connection, Engine, text
from sqlalchemy.exc import SQLAlchemyError
from sqlmodel import Session
from tenacity import (
    Retrying,
    before_sleep_log,
    retry_if_exception_type,
    stop_after_delay,
    wait_exponential,
)

from app.core.config import BACKEND_ROOT, Settings, get_settings
from app.core.db import DATABASE_CONNECT_TIMEOUT_SECONDS, get_engine, init_db
from app.core.logger import setup_logging

logger = logging.getLogger(__name__)

# Shared by every database-backed flavor so replicas serialize schema changes.
MIGRATION_LOCK_KEY = 7_461_001
DATABASE_WAIT_SECONDS = 300
DATABASE_RETRY_MAX_WAIT_SECONDS = 10
MIGRATION_LOCK_POLL_SECONDS = 0.5


class SchemaNotAtHeadError(RuntimeError):
    pass


class MigrationLockTimeoutError(RuntimeError):
    pass


def _alembic_config(path: Path | None = None) -> Config:
    config = Config(str(path or BACKEND_ROOT / "alembic.ini"))
    config.attributes["configure_logger"] = False
    return config


def _connect_with_retry(engine: Engine) -> Connection:
    retry_stop_seconds = (
        DATABASE_WAIT_SECONDS
        - DATABASE_RETRY_MAX_WAIT_SECONDS
        - DATABASE_CONNECT_TIMEOUT_SECONDS
    )
    retrying = Retrying(
        stop=stop_after_delay(retry_stop_seconds),
        wait=wait_exponential(multiplier=1, min=1, max=DATABASE_RETRY_MAX_WAIT_SECONDS),
        retry=retry_if_exception_type(SQLAlchemyError),
        before_sleep=before_sleep_log(logger, logging.WARNING),
        reraise=True,
    )
    for attempt in retrying:
        with attempt:
            return engine.connect()
    raise RuntimeError("Database connection retry loop ended unexpectedly")


def _heads(connection: Connection, config: Config) -> tuple[set[str], set[str]]:
    current = set(MigrationContext.configure(connection).get_current_heads())
    expected = set(ScriptDirectory.from_config(config).get_heads())
    connection.rollback()
    return current, expected


def _verify_head(connection: Connection, config: Config) -> None:
    current, expected = _heads(connection, config)
    if current != expected:
        raise SchemaNotAtHeadError(
            "Database schema revision does not match bundled Alembic head "
            f"(db_revision={sorted(current)}, bundled_head={sorted(expected)})."
        )


def _acquire_lock(connection: Connection, timeout_seconds: float) -> None:
    if connection.scalar(
        text("SELECT pg_try_advisory_lock(:key)"), {"key": MIGRATION_LOCK_KEY}
    ):
        connection.commit()
        logger.warning("Database migration lock acquired (pid=%s)", os.getpid())
        return

    connection.commit()
    logger.warning(
        "Database migration lock busy; waiting up to %s seconds (pid=%s)",
        timeout_seconds,
        os.getpid(),
    )
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        time.sleep(min(MIGRATION_LOCK_POLL_SECONDS, deadline - time.monotonic()))
        if connection.scalar(
            text("SELECT pg_try_advisory_lock(:key)"), {"key": MIGRATION_LOCK_KEY}
        ):
            connection.commit()
            logger.warning(
                "Database migration lock acquired after wait (pid=%s)", os.getpid()
            )
            return
        connection.commit()

    raise MigrationLockTimeoutError(
        f"Timed out after {timeout_seconds} seconds waiting for PostgreSQL migration "
        f"advisory lock {MIGRATION_LOCK_KEY}. Inspect pg_stat_activity and resolve "
        "the lock owner before retrying."
    )


def _release_lock(connection: Connection) -> None:
    try:
        connection.rollback()
        connection.execute(
            text("SELECT pg_advisory_unlock(:key)"), {"key": MIGRATION_LOCK_KEY}
        )
        connection.commit()
        logger.warning("Database migration lock released (pid=%s)", os.getpid())
    except SQLAlchemyError:
        # Closing the session also releases PostgreSQL advisory locks. Preserve the
        # original startup failure if the connection itself has become unusable.
        logger.exception("Could not explicitly release database migration lock")


def initialize_database(
    settings: Settings,
    engine: Engine,
    *,
    alembic_config: Config | None = None,
) -> None:
    """Migrate or verify, then seed, before the process can serve requests."""
    config = alembic_config or _alembic_config()
    connection = _connect_with_retry(engine)
    try:
        _acquire_lock(connection, settings.MIGRATION_LOCK_TIMEOUT_SECONDS)
        try:
            current, expected = _heads(connection, config)
            if settings.MIGRATE_ON_START and current != expected:
                logger.warning(
                    "Running Alembic migrations under database lock: %s -> %s (pid=%s)",
                    sorted(current),
                    sorted(expected),
                    os.getpid(),
                )
                config.attributes["connection"] = connection
                command.upgrade(config, "head")
                logger.warning("Database migrations completed (pid=%s)", os.getpid())
            elif settings.MIGRATE_ON_START:
                logger.warning(
                    "Database schema already at bundled Alembic head %s (pid=%s)",
                    sorted(expected),
                    os.getpid(),
                )
            else:
                logger.warning(
                    "MIGRATE_ON_START=false; verifying database revision %s against "
                    "bundled head %s (pid=%s)",
                    sorted(current),
                    sorted(expected),
                    os.getpid(),
                )

            _verify_head(connection, config)
            with Session(connection) as session:
                init_db(session, settings)
            logger.warning(
                "Database startup completed successfully (pid=%s)", os.getpid()
            )
        finally:
            _release_lock(connection)
    finally:
        connection.close()


def main() -> None:
    settings = get_settings()
    setup_logging(settings.EFFECTIVE_LOG_LEVEL)
    try:
        initialize_database(settings, get_engine())
    except Exception:
        logger.exception("Database startup failed")
        raise


if __name__ == "__main__":
    main()
