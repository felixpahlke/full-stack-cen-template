from pathlib import Path

import pytest
from pydantic import ValidationError

from app.core.config import REPO_ROOT, Environment, Settings

OAUTH_SECRET_NAMES = (
    "OAUTH2_PROXY_UPSTREAM_PASSWORD",
    "OAUTH2_PROXY_COOKIE_SECRET",
    "OAUTH2_PROXY_CLIENT_SECRET",
)


def settings_values(**overrides: object) -> dict[str, object]:
    return {
        "_env_file": None,
        "PROJECT_NAME": "OAuth tests",
        "POSTGRES_SERVER": "localhost",
        "POSTGRES_USER": "postgres",
        "POSTGRES_PASSWORD": "database-test-password",
        "POSTGRES_DB": "test",
        "OAUTH2_PROXY_UPSTREAM_PASSWORD": "upstream-test-password-0123456789abcdef",
        "OAUTH2_PROXY_COOKIE_SECRET": "cookie-test-secret-0123456789abcdef",
        "OAUTH2_PROXY_CLIENT_SECRET": "client-test-secret-0123456789abcdef",
        **overrides,
    }


def test_settings_use_the_repository_env_path_independent_of_working_directory(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    monkeypatch.chdir(tmp_path)
    settings = Settings(**settings_values())  # type: ignore[arg-type]
    assert settings.API_V1_STR == "/api/v1"
    assert settings.POSTGRES_SERVER == "localhost"


@pytest.mark.parametrize(
    "name",
    OAUTH_SECRET_NAMES,
)
@pytest.mark.parametrize("environment", Environment)
def test_every_runtime_rejects_placeholder_or_weak_oauth_secrets(
    name: str, environment: Environment
) -> None:
    with pytest.raises(
        ValidationError,
        match=rf"{name}.*Run `pnpm run dev` to generate local values",
    ):
        Settings(
            **settings_values(  # type: ignore[arg-type]
                ENVIRONMENT=environment, **{name: "changethis"}
            )
        )


def example_secret_placeholders() -> list[tuple[str, str, str]]:
    placeholders: list[tuple[str, str, str]] = []
    for filename in (".env.example", ".env.production.example"):
        values: dict[str, str] = {}
        for line in (REPO_ROOT / filename).read_text().splitlines():
            if "=" in line and not line.lstrip().startswith("#"):
                name, value = line.split("=", 1)
                values[name] = value.strip().strip('"').strip("'")
        placeholders.extend(
            (filename, name, values[name]) for name in OAUTH_SECRET_NAMES
        )
    return placeholders


@pytest.mark.parametrize(
    ("_filename", "name", "placeholder"),
    example_secret_placeholders(),
)
def test_every_example_oauth_secret_placeholder_is_refused(
    _filename: str, name: str, placeholder: str
) -> None:
    assert placeholder
    with pytest.raises(ValidationError, match=name):
        Settings(
            **settings_values(  # type: ignore[arg-type]
                ENVIRONMENT=Environment.LOCAL, **{name: placeholder}
            )
        )
