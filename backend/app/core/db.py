from functools import lru_cache
from typing import TYPE_CHECKING

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


if TYPE_CHECKING:
    engine: Engine


def __getattr__(name: str) -> Engine:
    """Keep the historical engine import lazy and factory-backed."""
    if name == "engine":
        return get_engine()
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")


def init_db(session: Session, settings: Settings | None = None) -> None:
    # OIDC principals are request-scoped; this flavor has no local user table to seed.
    del session, settings
