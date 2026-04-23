from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.routing import APIRoute
from starlette.middleware.cors import CORSMiddleware

from app.api.main import api_router
from app.core.config import settings
from app.core.logger import get_logger, log_exception, setup_logging

# Initialize logging
setup_logging()
logger = get_logger(__name__)


def custom_generate_unique_id(route: APIRoute) -> str:
    return f"{route.tags[0]}-{route.name}"


app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    generate_unique_id_function=custom_generate_unique_id,
    swagger_ui_parameters={"persistAuthorization": True},
)

# Global exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """
    Global exception handler that logs all unhandled exceptions with stack traces.
    """
    log_exception(
        logger,
        exc,
        context=f"Unhandled exception in {request.method} {request.url.path}",
    )
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "detail": "Internal server error occurred. Please contact support if the issue persists."
        },
    )

# Validation error handler with logging
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(
    request: Request, exc: RequestValidationError
) -> JSONResponse:
    """
    Handler for request validation errors with logging.
    """
    logger.warning(
        f"Validation error in {request.method} {request.url.path}: {exc.errors()}"
    )
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={"detail": exc.errors()},
    )

@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Log all incoming requests and responses."""
    logger.debug(f"Request: {request.method} {request.url.path}")

    try:
        response = await call_next(request)
        logger.debug(
            f"Response: {request.method} {request.url.path} - Status: {response.status_code}"
        )
        return response
    except Exception:
        logger.error(
            f"Request failed: {request.method} {request.url.path}", exc_info=True
        )
        raise

# Log application startup
@app.on_event("startup")
async def startup_event() -> None:
    """Log application startup."""
    logger.debug(f"Starting {settings.PROJECT_NAME} application")
    logger.debug(f"Environment: {settings.ENVIRONMENT}")
    logger.debug(f"API version: {settings.API_V1_STR}")

# Log application shutdown
@app.on_event("shutdown")
async def shutdown_event() -> None:
    """Log application shutdown."""
    logger.debug(f"Shutting down {settings.PROJECT_NAME} application")

# Set all CORS enabled origins
if settings.all_cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.all_cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

app.include_router(api_router, prefix=settings.API_V1_STR)
