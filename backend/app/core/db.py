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


def init_db(session: Session, settings: Settings) -> None:
    # OIDC principals are request-scoped; this flavor has no local user table to seed.
    del session, settings
