import logging
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
import app.core.logger as logger_module
import app.main as main_module
from app.core.config import LogLevel, Settings
from app.core.db import create_db_engine


def factory_settings() -> Settings:
    return Settings(  # type: ignore[call-arg]
        _env_file=None,
        PROJECT_NAME="Backend-only compatibility tests",
        API_KEY="backend-only-test-api-key",
        LOG_LEVEL=LogLevel.WARNING,
        POSTGRES_SERVER="unused",
        POSTGRES_USER="unused",
        POSTGRES_PASSWORD="database-test-password",
        POSTGRES_DB="test",
    )


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
    error_response = client.get("/extension-error")
    assert error_response.status_code == 418
    assert error_response.json() == {"handled": True}


def test_legacy_settings_engine_and_logging_use_factories(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    settings = factory_settings()
    engine = create_db_engine("sqlite://")
    monkeypatch.setattr(config_module, "get_settings", lambda: settings)
    monkeypatch.setattr(db_module, "get_engine", lambda: engine)
    monkeypatch.setattr(logger_module, "get_settings", lambda: settings)
    namespace: dict[str, object] = {}

    exec(
        "from app.core.config import settings\nfrom app.core.db import engine",
        namespace,
    )
    logger_module.setup_logging()

    assert namespace["settings"] is settings
    assert namespace["engine"] is engine
    assert logging.getLogger().level == logging.WARNING
    handler = logging.getLogger().handlers[0]
    assert isinstance(handler, logging.StreamHandler)
    assert handler.stream is sys.stderr
    engine.dispose()
