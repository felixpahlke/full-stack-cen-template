import pytest

from app.tests.conftest import (
    TEST_DATABASE_ALLOW_UNSAFE_NAME,
    guard_test_database_url,
)


def test_database_url_guard_requires_safe_name_or_explicit_override(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    unsafe_url = "postgresql+psycopg://postgres:secret@localhost/app"

    monkeypatch.delenv(TEST_DATABASE_ALLOW_UNSAFE_NAME, raising=False)
    with pytest.raises(RuntimeError, match=r"migrates.*DELETES data"):
        guard_test_database_url(unsafe_url)

    guard_test_database_url("postgresql+psycopg://postgres:secret@localhost/app_test")
    monkeypatch.setenv(TEST_DATABASE_ALLOW_UNSAFE_NAME, "1")
    guard_test_database_url(unsafe_url)
