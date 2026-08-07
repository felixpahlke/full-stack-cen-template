from collections.abc import Callable

from fastapi.testclient import TestClient

from app.core.config import API_V1_STR


def test_users_me_returns_forwarded_oidc_identity(
    client: TestClient,
    identity_headers: Callable[[str, str], dict[str, str]],
) -> None:
    response = client.get(
        f"{API_V1_STR}/users/me",
        headers=identity_headers("opaque-subject", "Person@Example.com"),
    )
    assert response.status_code == 200
    assert response.json() == {
        "id": "opaque-subject",
        "email": "person@example.com",
        "name": "Person",
    }
