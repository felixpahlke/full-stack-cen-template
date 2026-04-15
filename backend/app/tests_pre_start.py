from sqlalchemy import Engine
from sqlmodel import Session, select
from tenacity import retry, stop_after_attempt, wait_fixed

from app.core.db import engine
from app.core.logger import get_logger, log_exception, setup_logging

# Initialize logging before using logger
setup_logging()
logger = get_logger(__name__)

max_tries = 60 * 5  # 5 minutes
wait_seconds = 1


@retry(
    stop=stop_after_attempt(max_tries),
    wait=wait_fixed(wait_seconds),
)
def init(db_engine: Engine) -> None:
    try:
        logger.debug("Attempting to connect to test database...")
        # Try to create session to check if DB is awake
        with Session(db_engine) as session:
            session.exec(select(1))
        logger.debug("Test database connection successful")
    except Exception as e:
        log_exception(logger, e, context="Failed to connect to test database")
        raise e


def main() -> None:
    logger.debug("Initializing service")
    init(engine)
    logger.debug("Service finished initializing")


if __name__ == "__main__":
    main()
