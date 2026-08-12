import json
import os
import shutil
import subprocess
import sys
from base64 import b64encode
from collections.abc import Callable, Generator
from contextlib import suppress
from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config
from alembic.migration import MigrationContext
from alembic.script import ScriptDirectory
from fastapi.testclient import TestClient
from sqlalchemy import Engine, inspect, make_url
from sqlmodel import Session, delete
from testcontainers.community.postgres import PostgresContainer

from app.core.config import Settings
from app.core.db import create_db_engine
from app.main import create_app
from app.tables import Item

BACKEND_ROOT = Path(__file__).resolve().parents[2]
TEST_DATABASE_URL = "TEST_DATABASE_URL"
TEST_DATABASE_ALLOW_UNSAFE_NAME = "TEST_DATABASE_ALLOW_UNSAFE_NAME"
TEST_UPSTREAM_PASSWORD = "test-only-upstream-password-0123456789abcdef"


def configure_testcontainers_runtime() -> None:
    if os.getenv(TEST_DATABASE_URL) or os.getenv("DOCKER_HOST"):
        return
    docker = shutil.which("docker")
    if (
        docker
        and subprocess.run(
            [docker, "info"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        ).returncode
        == 0
    ):
        return
    podman = shutil.which("podman")
    if not podman:
        return
    info_result = subprocess.run(
        [podman, "info", "--format", "{{json .}}"], capture_output=True, text=True
    )
    if info_result.returncode != 0:
        return
    info = json.loads(info_result.stdout)
    if sys.platform == "linux":
        socket = info["host"]["remoteSocket"]["path"]
    else:
        inspect_result = subprocess.run(
            [
                podman,
                "machine",
                "inspect",
                "--format",
                "{{.ConnectionInfo.PodmanSocket.Path}}",
            ],
            capture_output=True,
            text=True,
        )
        if inspect_result.returncode != 0:
            return
        socket = inspect_result.stdout.strip()
    os.environ["DOCKER_HOST"] = (
        socket if socket.startswith("unix://") else f"unix://{socket}"
    )
    os.environ.setdefault("TESTCONTAINERS_RYUK_DISABLED", "true")


def guard_test_database_url(database_url: str) -> None:
    database_name = (make_url(database_url).database or "").lower()
    safe = (
        database_name == "test"
        or database_name.startswith(("test_", "test-"))
        or database_name.endswith(("_test", "-test"))
    )
    if safe or os.getenv(TEST_DATABASE_ALLOW_UNSAFE_NAME) == "1":
        return
    raise RuntimeError(
        f"Refusing unsafe {TEST_DATABASE_URL} database name {database_name!r}. "
        "The test suite migrates the target database and DELETES data from it. "
        "Use a strict test database name or explicitly set "
        f"{TEST_DATABASE_ALLOW_UNSAFE_NAME}=1."
    )


def create_postgres_container() -> PostgresContainer:
    return PostgresContainer(
        "postgres:12",
        driver="psycopg",
        username="test",
        password="test",
        dbname="test",
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

    configure_testcontainers_runtime()
    postgres = None
    try:
        postgres = create_postgres_container()
        postgres.start()
    except Exception as error:
        if postgres is not None:
            with suppress(Exception):
                postgres.stop()
        pytest.fail(
            "Could not start disposable PostgreSQL. Start Docker or Podman, or set "
            f"{TEST_DATABASE_URL} to an existing strict test database. ({error})",
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
    return Settings(  # type: ignore[call-arg]
        _env_file=None,
        PROJECT_NAME="OAuth proxy tests",
        POSTGRES_SERVER=url.host or "localhost",
        POSTGRES_PORT=url.port or 5432,
        POSTGRES_USER=url.username or "test",
        POSTGRES_PASSWORD=url.password or "",
        POSTGRES_DB=url.database or "test",
        OAUTH2_PROXY_UPSTREAM_PASSWORD=TEST_UPSTREAM_PASSWORD,
    )


@pytest.fixture(scope="session")
def migrated_database(database_url: str) -> None:
    config = Config(str(BACKEND_ROOT / "alembic.ini"))
    config.attributes["database_url"] = database_url
    scripts = ScriptDirectory.from_config(config)
    assert scripts.get_heads() == ["b9c8ef1280cd"]
    command.upgrade(config, "head")
    engine = create_db_engine(database_url)
    try:
        with engine.connect() as connection:
            assert MigrationContext.configure(connection).get_current_heads() == (
                "b9c8ef1280cd",
            )
        assert set(inspect(engine).get_table_names()) == {"alembic_version", "item"}
    finally:
        engine.dispose()


@pytest.fixture(scope="session")
def engine(database_url: str, migrated_database: None) -> Generator[Engine, None, None]:
    assert migrated_database is None
    db_engine = create_test_engine(database_url)
    yield db_engine
    db_engine.dispose()


@pytest.fixture(scope="session")
def db(engine: Engine) -> Generator[Session, None, None]:
    with Session(engine) as session:
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


@pytest.fixture
def identity_headers(settings: Settings) -> Callable[[str, str], dict[str, str]]:
    def build(
        subject: str = "non-uuid-subject", email: str = "person@example.com"
    ) -> dict[str, str]:
        credential = b64encode(
            f"proxy:{settings.OAUTH2_PROXY_UPSTREAM_PASSWORD}".encode()
        ).decode()
        return {
            "authorization": f"Basic {credential}",
            "x-forwarded-user": subject,
            "x-forwarded-email": email,
            "x-forwarded-preferred-username": email.split("@", 1)[0],
        }

    return build
