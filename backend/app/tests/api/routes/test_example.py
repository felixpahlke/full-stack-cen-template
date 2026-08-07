from fastapi.testclient import TestClient


def test_hello_world(client: TestClient, api_key_headers: dict[str, str]) -> None:
    response = client.get("/api/v1/example/hello", headers=api_key_headers)

    assert response.status_code == 200
    assert response.json() == {"message": "Hello, World!"}


def test_hello_world_requires_api_key(client: TestClient) -> None:
    response = client.get("/api/v1/example/hello")

    assert response.status_code in {401, 403}


def test_hello_world_rejects_wrong_api_key(client: TestClient) -> None:
    response = client.get(
        "/api/v1/example/hello", headers={"X-API-Key": "wrong-api-key"}
    )

    assert response.status_code == 401
    assert response.json() == {"detail": "Invalid API key"}


def test_health_check_is_public(client: TestClient) -> None:
    response = client.get("/api/v1/utils/health-check/")

    assert response.status_code == 200
    assert response.json() is True
