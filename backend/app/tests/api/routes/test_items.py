import uuid

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session

from app.core.config import Settings
from app.tests.utils.item import create_random_item


def item_routes(api_prefix: str) -> list[tuple[str, str, dict[str, str] | None]]:
    item_id = uuid.uuid4()
    payload = {"title": "Foo", "description": "Fighters"}
    return [
        ("GET", f"{api_prefix}/items/", None),
        ("GET", f"{api_prefix}/items/{item_id}", None),
        ("POST", f"{api_prefix}/items/", payload),
        ("PUT", f"{api_prefix}/items/{item_id}", payload),
        ("DELETE", f"{api_prefix}/items/{item_id}", None),
    ]


@pytest.mark.parametrize("credential", [None, "wrong-api-key"])
def test_all_item_routes_reject_invalid_api_keys(
    client: TestClient, settings: Settings, credential: str | None
) -> None:
    headers = {"X-API-Key": credential} if credential else None
    for method, path, payload in item_routes(settings.API_V1_STR):
        response = client.request(method, path, headers=headers, json=payload)
        assert response.status_code == 401, (method, path, response.text)


def test_create_item(
    client: TestClient, api_key_headers: dict[str, str], settings: Settings
) -> None:
    data = {"title": "Foo", "description": "Fighters"}
    response = client.post(
        f"{settings.API_V1_STR}/items/", headers=api_key_headers, json=data
    )
    assert response.status_code == 200
    content = response.json()
    assert content["title"] == data["title"]
    assert content["description"] == data["description"]
    assert "id" in content
    assert set(content) == {"id", "title", "description"}


def test_read_item(
    client: TestClient,
    api_key_headers: dict[str, str],
    settings: Settings,
    db: Session,
) -> None:
    item = create_random_item(db)
    response = client.get(
        f"{settings.API_V1_STR}/items/{item.id}", headers=api_key_headers
    )
    assert response.status_code == 200
    content = response.json()
    assert content["title"] == item.title
    assert content["description"] == item.description
    assert content["id"] == str(item.id)
    assert set(content) == {"id", "title", "description"}


def test_read_item_not_found(
    client: TestClient, api_key_headers: dict[str, str], settings: Settings
) -> None:
    response = client.get(
        f"{settings.API_V1_STR}/items/{uuid.uuid4()}", headers=api_key_headers
    )
    assert response.status_code == 404
    assert response.json()["detail"] == "Item not found"


def test_read_items(
    client: TestClient,
    api_key_headers: dict[str, str],
    settings: Settings,
    db: Session,
) -> None:
    create_random_item(db)
    create_random_item(db)
    response = client.get(f"{settings.API_V1_STR}/items/", headers=api_key_headers)
    assert response.status_code == 200
    content = response.json()
    assert len(content["data"]) >= 2
    assert all(set(item) == {"id", "title", "description"} for item in content["data"])


def test_update_item(
    client: TestClient,
    api_key_headers: dict[str, str],
    settings: Settings,
    db: Session,
) -> None:
    item = create_random_item(db)
    data = {"title": "Updated title", "description": "Updated description"}
    response = client.put(
        f"{settings.API_V1_STR}/items/{item.id}",
        headers=api_key_headers,
        json=data,
    )
    assert response.status_code == 200
    content = response.json()
    assert content["title"] == data["title"]
    assert content["description"] == data["description"]
    assert content["id"] == str(item.id)
    assert set(content) == {"id", "title", "description"}


def test_update_item_not_found(
    client: TestClient, api_key_headers: dict[str, str], settings: Settings
) -> None:
    data = {"title": "Updated title", "description": "Updated description"}
    response = client.put(
        f"{settings.API_V1_STR}/items/{uuid.uuid4()}",
        headers=api_key_headers,
        json=data,
    )
    assert response.status_code == 404
    assert response.json()["detail"] == "Item not found"


def test_delete_item(
    client: TestClient,
    api_key_headers: dict[str, str],
    settings: Settings,
    db: Session,
) -> None:
    item = create_random_item(db)
    response = client.delete(
        f"{settings.API_V1_STR}/items/{item.id}", headers=api_key_headers
    )
    assert response.status_code == 200
    content = response.json()
    assert content == {"message": "Item deleted successfully"}


def test_delete_item_not_found(
    client: TestClient, api_key_headers: dict[str, str], settings: Settings
) -> None:
    response = client.delete(
        f"{settings.API_V1_STR}/items/{uuid.uuid4()}", headers=api_key_headers
    )
    assert response.status_code == 404
    assert response.json()["detail"] == "Item not found"
