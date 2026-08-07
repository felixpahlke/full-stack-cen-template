import os
from collections.abc import Generator
from contextlib import suppress
from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import Engine, make_url
from sqlmodel import Session, delete
from testcontainers.community.postgres import PostgresContainer

from app.core.config import Settings
from app.core.db import create_db_engine, init_db
from app.main import create_app
from app.tables import Item

TEST_DATABASE_URL = "TEST_DATABASE_URL"
TEST_DATABASE_ALLOW_UNSAFE_NAME = "TEST_DATABASE_ALLOW_UNSAFE_NAME"
TEST_DATABASE_CREDENTIALS = {"username": "test", "password": "test", "dbname": "test"}
BACKEND_ROOT = Path(__file__).resolve().parents[2]


def guard_test_database_url(database_url: str) -> None:
    database_name = make_url(database_url).database or ""
    normalized_name = database_name.lower()
    if (
        normalized_name == "test"
        or normalized_name.endswith(("_test", "-test"))
        or normalized_name.startswith(("test_", "test-"))
    ):
        return
    if os.getenv(TEST_DATABASE_ALLOW_UNSAFE_NAME) == "1":
        return
    raise RuntimeError(
        f"Refusing unsafe {TEST_DATABASE_URL} database name {database_name!r}. "
        "The test suite migrates the target database and DELETES data from it. "
        "Use test, a test_ or test- prefix, or an _test or -test suffix, or set "
        f"{TEST_DATABASE_ALLOW_UNSAFE_NAME}=1 to explicitly allow this database."
    )


def create_postgres_container() -> PostgresContainer:
    return PostgresContainer(
        "postgres:12", driver="psycopg", **TEST_DATABASE_CREDENTIALS
    )


def create_test_engine(database_url: str) -> Engine:
    return create_db_engine(database_url)


@pytest.fixture(scope="session")
def database_url() -> Generator[str, None, None]:
    existing_url = os.getenv(TEST_DATABASE_URL)
    if existing_url:
        guard_test_database_url(existing_url)
        yield existing_url
        return

    postgres = None
    try:
        postgres = create_postgres_container()
        postgres.start()
    except Exception as error:
        if postgres is not None:
            with suppress(Exception):
                postgres.stop()
        pytest.fail(
            "Could not start disposable PostgreSQL. Start Docker, or set "
            f"{TEST_DATABASE_URL} to an existing test database. ({error})",
            pytrace=False,
        )

    try:
        assert postgres is not None
        yield postgres.get_connection_url()
    finally:
        postgres.stop()


@pytest.fixture(scope="session")
def settings(database_url: str) -> Settings:
    url = make_url(database_url)
    return Settings(
        _env_file=None,
        PROJECT_NAME="Backend tests",
        API_KEY="backend-test-api-key",
        POSTGRES_SERVER=url.host or "localhost",
        POSTGRES_PORT=url.port or 5432,
        POSTGRES_USER=url.username or "test",
        POSTGRES_PASSWORD=url.password or "",
        POSTGRES_DB=url.database or "test",
    )


@pytest.fixture(scope="session")
def migrated_database(database_url: str) -> None:
    config = Config(str(BACKEND_ROOT / "alembic.ini"))
    config.attributes["database_url"] = database_url
    command.upgrade(config, "head")


@pytest.fixture(scope="session")
def engine(database_url: str, migrated_database: None) -> Generator[Engine, None, None]:
    assert migrated_database is None
    db_engine = create_test_engine(database_url)
    yield db_engine
    db_engine.dispose()


@pytest.fixture(scope="session")
def db(engine: Engine) -> Generator[Session, None, None]:
    with Session(engine) as session:
        init_db(session)
        session.execute(delete(Item))
        session.commit()
        yield session
        session.execute(delete(Item))
        session.commit()


@pytest.fixture(scope="module")
def client(
    settings: Settings, engine: Engine, db: Session
) -> Generator[TestClient, None, None]:
    assert db is not None
    with TestClient(create_app(settings=settings, engine=engine)) as test_client:
        yield test_client


@pytest.fixture(scope="module")
def api_key_headers(settings: Settings) -> dict[str, str]:
    return {"X-API-Key": settings.API_KEY}
