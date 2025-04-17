from fastapi.testclient import TestClient


def test_hello_world(client: TestClient) -> None:
    """
    Test the hello world endpoint returns the expected response.
    """
    response = client.get("/hello")
    assert response.status_code == 200
    content = response.json()
    assert content["message"] == "Hello, World!"
    assert isinstance(content, dict)
    assert isinstance(content["message"], str)
