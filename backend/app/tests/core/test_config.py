import subprocess
import sys
from collections.abc import Awaitable, Callable

import pytest
from fastapi import APIRouter, FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.testclient import TestClient
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response

import app.core.config as config_module
import app.core.db as db_module
import app.main as main_module
from app.core.config import API_V1_STR, ENV_FILE, REPO_ROOT, Settings
from app.core.db import create_db_engine, get_engine
from app.main import create_app


def factory_settings(**overrides: object) -> Settings:
    values: dict[str, object] = {
        "PROJECT_NAME": "Factory test",
        "POSTGRES_SERVER": "unused",
        "POSTGRES_USER": "unused",
        "FIRST_SUPERUSER": "admin@example.com",
        "FIRST_SUPERUSER_PASSWORD": "factory-test-password",
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

    schema = app.openapi()

    assert app.openapi_url == "/custom/openapi.json"
    assert "/custom/users/me" in schema["paths"]
    assert (
        schema["components"]["securitySchemes"]["OAuth2PasswordBearer"]["flows"][
            "password"
        ]["tokenUrl"]
        == "/custom/login/access-token"
    )
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


def test_exported_app_is_the_real_customizable_application(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    settings = factory_settings()
    monkeypatch.setattr(main_module, "get_settings", lambda: settings)
    monkeypatch.delattr(main_module, "app", raising=False)
    namespace: dict[str, object] = {}

    exec("from app.main import app", namespace)
    app = namespace["app"]

    assert type(app) is FastAPI
    assert app.openapi()["paths"]

    router = APIRouter()

    @router.get("/extension")
    def extension_route() -> dict[str, bool]:
        return {"included": True}

    class ExtensionError(Exception):
        pass

    @router.get("/extension-error")
    def extension_error() -> None:
        raise ExtensionError

    async def add_extension_header(
        request: Request,
        call_next: Callable[[Request], Awaitable[Response]],
    ) -> Response:
        response = await call_next(request)
        response.headers["x-extension-middleware"] = "active"
        return response

    async def handle_extension_error(
        _request: Request, _error: Exception
    ) -> JSONResponse:
        return JSONResponse({"handled": True}, status_code=418)

    app.include_router(router)
    app.add_middleware(BaseHTTPMiddleware, dispatch=add_extension_header)
    app.add_exception_handler(ExtensionError, handle_extension_error)

    client = TestClient(app, raise_server_exceptions=False)
    response = client.get("/extension")
    assert response.json() == {"included": True}
    assert response.headers["x-extension-middleware"] == "active"
    app.openapi_schema = None
    assert "/extension" in app.openapi()["paths"]

    error_response = client.get("/extension-error")
    assert error_response.status_code == 418
    assert error_response.json() == {"handled": True}


def test_legacy_settings_and_engine_imports_use_factories(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    settings = factory_settings()
    engine = create_db_engine("sqlite://")
    monkeypatch.setattr(config_module, "get_settings", lambda: settings)
    monkeypatch.setattr(db_module, "get_engine", lambda: engine)
    namespace: dict[str, object] = {}

    exec(
        "from app.core.config import settings\nfrom app.core.db import engine",
        namespace,
    )

    assert namespace["settings"] is settings
    assert namespace["engine"] is engine
    engine.dispose()
