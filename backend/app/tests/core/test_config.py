import pytest
from pydantic import ValidationError

from app.core.config import Environment, Settings


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
    monkeypatch: pytest.MonkeyPatch, tmp_path
) -> None:
    monkeypatch.chdir(tmp_path)
    settings = Settings(**settings_values())
    assert settings.API_V1_STR == "/api/v1"
    assert settings.POSTGRES_SERVER == "localhost"


@pytest.mark.parametrize(
    "name",
    [
        "OAUTH2_PROXY_UPSTREAM_PASSWORD",
        "OAUTH2_PROXY_COOKIE_SECRET",
        "OAUTH2_PROXY_CLIENT_SECRET",
    ],
)
def test_non_local_runtime_rejects_placeholder_or_weak_oauth_secrets(name: str) -> None:
    with pytest.raises(ValidationError, match=name):
        Settings(
            **settings_values(
                ENVIRONMENT=Environment.PRODUCTION, **{name: "replace-me"}
            )
        )


def test_local_backend_also_requires_the_private_upstream_credential() -> None:
    with pytest.raises(ValidationError, match="OAUTH2_PROXY_UPSTREAM_PASSWORD"):
        Settings(
            **settings_values(
                OAUTH2_PROXY_UPSTREAM_PASSWORD="generate-on-first-dev-run"
            )
        )
