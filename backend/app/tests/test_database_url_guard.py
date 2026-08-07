import pytest

from app.tests.conftest import (
    TEST_DATABASE_ALLOW_UNSAFE_NAME,
    create_postgres_container,
    create_test_engine,
    guard_test_database_url,
)


@pytest.mark.parametrize(
    "database_name", ["test", "app_test", "app-test", "test_app", "test-app"]
)
def test_database_url_guard_accepts_strict_test_names(
    database_name: str, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.delenv(TEST_DATABASE_ALLOW_UNSAFE_NAME, raising=False)
    guard_test_database_url(
        f"postgresql+psycopg://postgres:secret@localhost/{database_name}"
    )


@pytest.mark.parametrize(
    "database_name", ["latest", "contest", "mytest", "testapp", "app"]
)
def test_database_url_guard_rejects_unsafe_names(
    database_name: str, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.delenv(TEST_DATABASE_ALLOW_UNSAFE_NAME, raising=False)
    with pytest.raises(RuntimeError, match=r"migrates.*DELETES data"):
        guard_test_database_url(
            f"postgresql+psycopg://postgres:secret@localhost/{database_name}"
        )


def test_database_url_guard_allows_explicit_override(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    unsafe_url = "postgresql+psycopg://postgres:secret@localhost/app"
    monkeypatch.setenv(TEST_DATABASE_ALLOW_UNSAFE_NAME, "1")
    guard_test_database_url(unsafe_url)


def test_test_engine_preserves_database_url_query() -> None:
    engine = create_test_engine(
        "postgresql+psycopg://test:test@localhost/test?application_name=probe"
    )
    try:
        assert engine.url.query["application_name"] == "probe"
    finally:
        engine.dispose()


def test_postgres_container_ignores_host_credentials(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("POSTGRES_USER", "host-user")
    monkeypatch.setenv("POSTGRES_PASSWORD", "host-secret")
    monkeypatch.setenv("POSTGRES_DB", "host-database")

    postgres = create_postgres_container()

    assert (postgres.username, postgres.password, postgres.dbname) == (
        "test",
        "test",
        "test",
    )
