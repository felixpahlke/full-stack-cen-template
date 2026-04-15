from sqlmodel import Session

from app.core.db import engine, init_db
from app.core.logger import get_logger, setup_logging

# Initialize logging before using logger
setup_logging()
logger = get_logger(__name__)


def init() -> None:
    with Session(engine) as session:
        init_db(session)


def main() -> None:
    logger.debug("Creating initial data")
    init()
    logger.info("Initial data created")


if __name__ == "__main__":
    main()
