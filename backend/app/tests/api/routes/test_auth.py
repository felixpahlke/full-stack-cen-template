from base64 import b64encode
from collections.abc import Callable

import pytest
from fastapi.testclient import TestClient

from app.core.config import API_V1_STR, Settings


def test_missing_identity_or_proxy_credential_is_rejected(
    client: TestClient,
    settings: Settings,
    identity_headers: Callable[[str, str], dict[str, str]],
) -> None:
    assert client.get(f"{API_V1_STR}/users/me").status_code == 401
    forged = identity_headers("forged", "forged@example.com")
    forged.pop("authorization")
    assert client.get(f"{API_V1_STR}/users/me", headers=forged).status_code == 401
    credential = b64encode(
        f"proxy:{settings.OAUTH2_PROXY_UPSTREAM_PASSWORD}".encode()
    ).decode()
    assert (
        client.get(
            f"{API_V1_STR}/users/me", headers={"authorization": f"Basic {credential}"}
        ).status_code
        == 401
    )


@pytest.mark.parametrize(
    "authorization",
    [
        "Bearer client-token",
        "Basic " + b64encode(b"proxy:wrong-password").decode(),
        "Basic not-base64!",
    ],
)
def test_client_authorization_cannot_authenticate(
    client: TestClient,
    authorization: str,
    identity_headers: Callable[[str, str], dict[str, str]],
) -> None:
    headers = identity_headers("forged", "forged@example.com")
    headers["authorization"] = authorization
    assert client.get(f"{API_V1_STR}/users/me", headers=headers).status_code == 401


@pytest.mark.parametrize(
    "name",
    ["x_forwarded_user", "x_forwarded_email", "x_forwarded_preferred_username"],
)
def test_underscore_identity_aliases_fail_closed(
    client: TestClient,
    name: str,
    identity_headers: Callable[[str, str], dict[str, str]],
) -> None:
    headers = identity_headers("subject", "person@example.com")
    headers[name] = "forged"
    assert client.get(f"{API_V1_STR}/users/me", headers=headers).status_code == 401


@pytest.mark.parametrize(
    "duplicate_name",
    ["authorization", "x-forwarded-user", "x-forwarded-email"],
)
def test_duplicate_protected_headers_fail_closed(
    client: TestClient,
    duplicate_name: str,
    identity_headers: Callable[[str, str], dict[str, str]],
) -> None:
    headers = list(identity_headers("subject", "person@example.com").items())
    headers.append((duplicate_name, "forged"))
    assert client.get(f"{API_V1_STR}/users/me", headers=headers).status_code == 401
