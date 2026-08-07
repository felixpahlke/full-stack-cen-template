from functools import lru_cache

from sqlalchemy import Engine, make_url
from sqlmodel import Session, create_engine

from app.core.config import Settings, get_settings

DATABASE_CONNECT_TIMEOUT_SECONDS = 10


def create_db_engine(database_url: str) -> Engine:
    connect_args = {}
    if make_url(database_url).get_backend_name() == "postgresql":
        connect_args["connect_timeout"] = DATABASE_CONNECT_TIMEOUT_SECONDS
    return create_engine(database_url, connect_args=connect_args)


@lru_cache
def get_engine() -> Engine:
    return create_db_engine(str(get_settings().SQLALCHEMY_DATABASE_URI))


# make sure all SQLModel models are imported (app.tables) before initializing DB
# otherwise, SQLModel might fail to initialize relationships properly
# for more details: https://github.com/fastapi/full-stack-fastapi-template/issues/28


def init_db(session: Session, settings: Settings | None = None) -> None:
    # Tables should be created with Alembic migrations
    # But if you don't want to use migrations, create
    # the tables un-commenting the next lines
    # from sqlmodel import SQLModel

    # This works because the models are already imported and registered from app.tables
    # SQLModel.metadata.create_all(engine)

    # You can add initial data here
    del session, settings
