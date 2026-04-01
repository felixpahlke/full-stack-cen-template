import json
from unittest.mock import AsyncMock, patch

import pytest

from app.core.telemetry import (
    build_flavor_event_body,
    get_host_kind,
    get_tracking_url,
    send_flavor_tracking_event,
)


def test_get_host_kind_detects_environment_kind() -> None:
    assert get_host_kind("local") == "local"
    assert get_host_kind("production") == "remote"


def test_get_tracking_url_uses_branch_flavor() -> None:
    assert get_tracking_url("local") == "http://localhost/backend-only-no-db"
    assert get_tracking_url("production") == "https://backend-only-no-db"


def test_build_flavor_event_body_marks_backend_source() -> None:
    payload = json.loads(build_flavor_event_body(environment="local"))

    assert payload["n"] == "Flavor Used"
    assert payload["p"]["tracking_source"] == "backend"
    assert payload["p"]["app_flavor"] == "backend-only-no-db"
    assert payload["u"] == "http://localhost/backend-only-no-db"


@pytest.mark.anyio
async def test_send_flavor_tracking_event_posts_plain_text_payload() -> None:
    post_mock = AsyncMock()
    client_mock = AsyncMock()
    client_mock.__aenter__.return_value = client_mock
    client_mock.post = post_mock

    with patch("app.core.telemetry.httpx.AsyncClient", return_value=client_mock):
        await send_flavor_tracking_event(environment="local")

    post_mock.assert_awaited_once()
    _, kwargs = post_mock.await_args
    assert kwargs["headers"] == {"Content-Type": "text/plain"}
