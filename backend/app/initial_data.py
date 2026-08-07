import logging

from sqlmodel import Session

from app.core.config import get_settings
from app.core.db import get_engine, init_db

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def init() -> None:
    with Session(get_engine()) as session:
        init_db(session, get_settings())


def main() -> None:
    logger.info("Creating initial data")
    init()
    logger.info("Initial data created")


if __name__ == "__main__":
    main()
