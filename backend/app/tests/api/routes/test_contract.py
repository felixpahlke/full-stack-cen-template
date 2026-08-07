from fastapi import FastAPI
from fastapi.routing import APIRoute
from fastapi.testclient import TestClient

from app.core.config import Settings


def business_routes(app: FastAPI) -> set[tuple[str, str]]:
    routes: set[tuple[str, str]] = set()
    for route in app.routes:
        if isinstance(route, APIRoute):
            routes.update((method, route.path) for method in route.methods)
            continue
        contexts = getattr(route, "effective_route_contexts", None)
        if contexts:
            for context in contexts():
                routes.update((method, context.path) for method in context.methods)
    return routes


def test_route_contract(client: TestClient) -> None:
    assert business_routes(client.app) == {
        ("GET", "/api/v1/items/"),
        ("GET", "/api/v1/items/{id}"),
        ("POST", "/api/v1/items/"),
        ("PUT", "/api/v1/items/{id}"),
        ("DELETE", "/api/v1/items/{id}"),
        ("GET", "/api/v1/utils/health-check/"),
    }


def test_health_check_is_public_and_hidden_from_openapi(
    client: TestClient, settings: Settings
) -> None:
    response = client.get(f"{settings.API_V1_STR}/utils/health-check/")
    assert response.status_code == 200
    assert response.json() is True

    schema = client.get(f"{settings.API_V1_STR}/openapi.json").json()
    assert f"{settings.API_V1_STR}/utils/health-check/" not in schema["paths"]
