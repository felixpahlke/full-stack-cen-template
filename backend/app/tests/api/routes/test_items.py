import uuid
from collections.abc import Callable

from fastapi.testclient import TestClient

from app.core.config import API_V1_STR

IdentityHeaders = Callable[[str, str], dict[str, str]]


def test_non_uuid_subject_owned_item_crud_round_trip(
    client: TestClient, identity_headers: IdentityHeaders
) -> None:
    headers = identity_headers("oidc|tenant:person@example.com", "person@example.com")
    created = client.post(
        f"{API_V1_STR}/items/",
        headers=headers,
        json={"title": "OAuth item", "description": "Opaque subject owned"},
    )
    assert created.status_code == 200
    item = created.json()
    assert item["owner_id"] == "oidc|tenant:person@example.com"

    listing = client.get(f"{API_V1_STR}/items/", headers=headers)
    assert listing.status_code == 200
    assert item in listing.json()["data"]

    fetched = client.get(f"{API_V1_STR}/items/{item['id']}", headers=headers)
    assert fetched.status_code == 200
    assert fetched.json() == item

    updated = client.put(
        f"{API_V1_STR}/items/{item['id']}",
        headers=headers,
        json={"title": "Updated", "description": "Still subject owned"},
    )
    assert updated.status_code == 200
    assert updated.json()["owner_id"] == "oidc|tenant:person@example.com"

    deleted = client.delete(f"{API_V1_STR}/items/{item['id']}", headers=headers)
    assert deleted.status_code == 200
    assert deleted.json() == {"message": "Item deleted successfully"}
    assert (
        client.get(f"{API_V1_STR}/items/{item['id']}", headers=headers).status_code
        == 404
    )


def test_other_subject_cannot_list_read_update_or_delete_item(
    client: TestClient, identity_headers: IdentityHeaders
) -> None:
    owner = identity_headers("subject-owner", "owner@example.com")
    other = identity_headers("subject-other", "other@example.com")
    item = client.post(
        f"{API_V1_STR}/items/", headers=owner, json={"title": "Private"}
    ).json()

    assert client.get(f"{API_V1_STR}/items/", headers=other).json() == {
        "data": [],
        "count": 0,
    }
    assert (
        client.get(f"{API_V1_STR}/items/{item['id']}", headers=other).status_code == 400
    )
    assert (
        client.put(
            f"{API_V1_STR}/items/{item['id']}",
            headers=other,
            json={"title": "Stolen"},
        ).status_code
        == 400
    )
    assert (
        client.delete(f"{API_V1_STR}/items/{item['id']}", headers=other).status_code
        == 400
    )
    assert (
        client.delete(f"{API_V1_STR}/items/{item['id']}", headers=owner).status_code
        == 200
    )


def test_items_require_authenticated_forwarded_identity(client: TestClient) -> None:
    assert client.get(f"{API_V1_STR}/items/").status_code == 401
    assert client.get(f"{API_V1_STR}/items/{uuid.uuid4()}").status_code == 401
