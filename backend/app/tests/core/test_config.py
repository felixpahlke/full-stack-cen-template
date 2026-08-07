import subprocess
import sys

from app.core.config import API_V1_STR, ENV_FILE, REPO_ROOT, Settings
from app.core.db import create_db_engine, get_engine
from app.main import create_app


def factory_settings(**overrides: object) -> Settings:
    values: dict[str, object] = {
        "PROJECT_NAME": "Factory test",
        "API_KEY": "factory-test-api-key",
        "POSTGRES_SERVER": "unused",
        "POSTGRES_USER": "unused",
    }
    values.update(overrides)
    return Settings(_env_file=None, **values)  # type: ignore[call-arg,arg-type]


def test_env_file_is_anchored_to_repo_root() -> None:
    assert ENV_FILE == REPO_ROOT / ".env"
    assert Settings.model_config["env_file"] == ENV_FILE


def test_factories_accept_injected_settings_and_database_url() -> None:
    settings = factory_settings()
    engine = create_db_engine("sqlite://")
    app = create_app(settings=settings, engine=engine)

    assert app.title == "Factory test"
    assert app.state.settings is settings
    assert app.dependency_overrides[get_engine]() is engine
    engine.dispose()


def test_app_factory_builds_engine_from_injected_settings() -> None:
    settings = factory_settings(
        POSTGRES_SERVER="injected-db",
        POSTGRES_PORT=5439,
        POSTGRES_USER="injected-user",
        POSTGRES_DB="injected-database",
    )
    app = create_app(settings=settings)
    engine = app.dependency_overrides[get_engine]()

    assert engine.url.render_as_string(hide_password=False) == str(
        settings.SQLALCHEMY_DATABASE_URI
    )
    assert app.openapi_url == f"{API_V1_STR}/openapi.json"
    assert Settings.model_fields["API_V1_STR"].default == API_V1_STR
    engine.dispose()


def test_app_factory_uses_injected_api_prefix_everywhere() -> None:
    settings = factory_settings(API_V1_STR="/custom")
    engine = create_db_engine("sqlite://")
    app = create_app(settings=settings, engine=engine)

    assert app.openapi_url == "/custom/openapi.json"
    assert sorted(app.openapi()["paths"]) == [
        "/custom/items/",
        "/custom/items/{id}",
    ]
    engine.dispose()


def test_importing_app_main_needs_no_environment() -> None:
    result = subprocess.run(
        [sys.executable, "-c", "import app.main"],
        cwd=REPO_ROOT / "backend",
        env={"PYTHONPATH": str(REPO_ROOT / "backend")},
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr
