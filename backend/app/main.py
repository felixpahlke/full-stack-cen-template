import asyncio
from collections.abc import Callable
from contextlib import asynccontextmanager
from time import perf_counter

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.routing import APIRoute
from starlette.middleware.cors import CORSMiddleware
from starlette.types import Receive, Scope, Send

from app.api.main import api_router
from app.core.config import Settings, get_settings
from app.core.logger import get_logger, setup_logging
from app.core.telemetry import send_flavor_tracking_event

logger = get_logger(__name__)


def custom_generate_unique_id(route: APIRoute) -> str:
    return f"{route.tags[0]}-{route.name}"


def create_app(*, settings: Settings | None = None) -> FastAPI:
    app_settings = settings or get_settings()
    setup_logging(app_settings.EFFECTIVE_LOG_LEVEL)

    @asynccontextmanager
    async def lifespan(_app: FastAPI):
        logger.info("Starting %s application", app_settings.PROJECT_NAME)
        logger.info("Environment: %s", app_settings.ENVIRONMENT)
        logger.info("API version: %s", app_settings.API_V1_STR)
        if app_settings.TELEMETRY_ENABLED:
            asyncio.create_task(
                send_flavor_tracking_event(environment=app_settings.ENVIRONMENT)
            )
        yield
        logger.info("Shutting down %s application", app_settings.PROJECT_NAME)

    app = FastAPI(
        title=app_settings.PROJECT_NAME,
        openapi_url=f"{app_settings.API_V1_STR}/openapi.json",
        generate_unique_id_function=custom_generate_unique_id,
        swagger_ui_parameters={"persistAuthorization": True},
        lifespan=lifespan,
    )
    app.state.settings = app_settings

    if settings is not None:
        app.dependency_overrides[get_settings] = lambda: app_settings

    @app.exception_handler(Exception)
    async def global_exception_handler(
        request: Request, exc: Exception
    ) -> JSONResponse:
        """Log unhandled exceptions and return a stable error response."""
        logger.error(
            "Unhandled exception in %s %s",
            request.method,
            request.url.path,
            exc_info=(type(exc), exc, exc.__traceback__),
        )
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={
                "detail": "Internal server error occurred. Please contact support if the issue persists."
            },
        )

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(
        request: Request, exc: RequestValidationError
    ) -> JSONResponse:
        """Log request validation failures."""
        logger.warning("Validation error in %s %s", request.method, request.url.path)
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            content={"detail": exc.errors()},
        )

    @app.middleware("http")
    async def log_requests(request: Request, call_next):
        """Log one summary line for each completed request."""
        start_time = perf_counter()
        response = await call_next(request)
        duration_ms = (perf_counter() - start_time) * 1000
        logger.info(
            "%s %s %s %.2fms",
            request.method,
            request.url.path,
            response.status_code,
            duration_ms,
        )
        return response

    if app_settings.all_cors_origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=app_settings.all_cors_origins,
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )

    app.include_router(api_router, prefix=app_settings.API_V1_STR)
    return app


class FactoryBackedFastAPI(FastAPI):
    """Keep file-based FastAPI CLI entrypoints lazy and factory-backed."""

    def __init__(self, factory: Callable[[], FastAPI]) -> None:
        super().__init__()
        self._factory = factory
        self._delegate: FastAPI | None = None

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if self._delegate is None:
            self._delegate = self._factory()
        await self._delegate(scope, receive, send)


app = FactoryBackedFastAPI(create_app)
