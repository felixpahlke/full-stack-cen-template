import os
from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import Engine, make_url
from sqlmodel import Session, delete

from app.core.config import Settings, get_settings
from app.core.db import create_db_engine, init_db
from app.main import create_app
from app.tables import Item, User
from app.tests.utils.user import authentication_token_from_email
from app.tests.utils.utils import get_superuser_token_headers

TEST_DATABASE_URL = "TEST_DATABASE_URL"
TEST_DATABASE_ALLOW_UNSAFE_NAME = "TEST_DATABASE_ALLOW_UNSAFE_NAME"


def guard_test_database_url(database_url: str) -> None:
    database_name = make_url(database_url).database or ""
    if "test" in database_name.lower():
        return
    if os.getenv(TEST_DATABASE_ALLOW_UNSAFE_NAME) == "1":
        return
    raise RuntimeError(
        f"Refusing unsafe {TEST_DATABASE_URL} database name {database_name!r}. "
        "The test suite migrates the target database and DELETES data from it. "
        "Use a database name containing 'test' (for example, app_test), or set "
        f"{TEST_DATABASE_ALLOW_UNSAFE_NAME}=1 to explicitly allow this database."
    )


@pytest.fixture(scope="session")
def settings() -> Settings:
    app_settings = get_settings()
    database_url = os.getenv(TEST_DATABASE_URL)
    if not database_url:
        return app_settings

    url = make_url(database_url)
    return app_settings.model_copy(
        update={
            "POSTGRES_SERVER": url.host or "localhost",
            "POSTGRES_PORT": url.port or 5432,
            "POSTGRES_USER": url.username or "postgres",
            "POSTGRES_PASSWORD": url.password or "",
            "POSTGRES_DB": url.database or "",
        }
    )


@pytest.fixture(scope="session")
def engine(settings: Settings) -> Generator[Engine, None, None]:
    database_url = str(settings.SQLALCHEMY_DATABASE_URI)
    guard_test_database_url(database_url)
    db_engine = create_db_engine(database_url)
    yield db_engine
    db_engine.dispose()


@pytest.fixture(scope="session")
def db(engine: Engine, settings: Settings) -> Generator[Session, None, None]:
    with Session(engine) as session:
        init_db(session, settings)
        yield session
        session.execute(delete(Item))
        session.execute(delete(User))
        session.commit()


@pytest.fixture(scope="module")
def client(
    settings: Settings, engine: Engine, db: Session
) -> Generator[TestClient, None, None]:
    assert db is not None
    with TestClient(create_app(settings=settings, engine=engine)) as test_client:
        yield test_client


@pytest.fixture(scope="module")
def superuser_token_headers(client: TestClient, settings: Settings) -> dict[str, str]:
    return get_superuser_token_headers(client, settings)


@pytest.fixture(scope="module")
def normal_user_token_headers(
    client: TestClient, db: Session, settings: Settings
) -> dict[str, str]:
    return authentication_token_from_email(
        client=client, email=settings.EMAIL_TEST_USER, db=db
    )
