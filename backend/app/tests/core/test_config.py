import subprocess
import sys
from collections.abc import Iterator

import pytest
from fastapi import FastAPI
from fastapi.routing import APIRoute

from app.core.config import API_V1_STR, ENV_FILE, REPO_ROOT, Settings, get_settings
from app.main import create_app


def factory_settings(**overrides: object) -> Settings:
    values: dict[str, object] = {
        "PROJECT_NAME": "Factory test",
        "API_KEY": "factory-test-key",
        "TELEMETRY_ENABLED": False,
    }
    values.update(overrides)
    return Settings(_env_file=None, **values)  # type: ignore[call-arg,arg-type]


def test_env_file_is_anchored_to_repo_root() -> None:
    assert ENV_FILE == REPO_ROOT / ".env"
    assert Settings.model_config["env_file"] == ENV_FILE


def test_app_factory_accepts_injected_settings() -> None:
    settings = factory_settings()

    created_app = create_app(settings=settings)

    assert created_app.title == "Factory test"
    assert created_app.state.settings is settings
    assert created_app.dependency_overrides[get_settings]() is settings


def test_app_factory_uses_injected_api_prefix_everywhere() -> None:
    settings = factory_settings(API_V1_STR="/custom")

    created_app = create_app(settings=settings)
    routes = set(product_route_dump(created_app))

    assert created_app.openapi_url == "/custom/openapi.json"
    assert routes == {
        ("/custom/example/hello", ("GET",)),
        ("/custom/utils/health-check/", ("GET",)),
    }
    assert Settings.model_fields["API_V1_STR"].default == API_V1_STR


def test_get_settings_is_cached(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("PROJECT_NAME", "Cached settings")
    monkeypatch.setenv("API_KEY", "cached-test-key")
    get_settings.cache_clear()
    try:
        assert get_settings() is get_settings()
    finally:
        get_settings.cache_clear()


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


def product_route_dump(
    created_app: FastAPI,
) -> Iterator[tuple[str, tuple[str, ...]]]:
    """Return application routes across static and dynamic FastAPI routers."""
    for route in created_app.routes:
        effective_routes = getattr(route, "effective_route_contexts", None)
        if effective_routes is not None:
            for context in effective_routes():
                yield context.path, tuple(sorted(context.methods))
        elif isinstance(route, APIRoute):
            assert route.methods is not None
            yield route.path, tuple(sorted(route.methods))
