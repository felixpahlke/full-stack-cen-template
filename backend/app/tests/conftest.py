from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient

from app.core.config import Settings
from app.main import create_app

TEST_API_KEY = "test-api-key"


@pytest.fixture(scope="module")
def settings() -> Settings:
    return Settings(  # type: ignore[call-arg]
        _env_file=None,
        PROJECT_NAME="Test API",
        API_KEY=TEST_API_KEY,
        TELEMETRY_ENABLED=False,
    )


@pytest.fixture(scope="module")
def client(settings: Settings) -> Generator[TestClient, None, None]:
    with TestClient(create_app(settings=settings)) as test_client:
        yield test_client


@pytest.fixture(scope="module")
def api_key_headers() -> dict[str, str]:
    return {"X-API-Key": TEST_API_KEY}
