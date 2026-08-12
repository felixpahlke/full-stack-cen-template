import re
from pathlib import Path
from typing import cast

from fastapi.routing import APIRoute

from app.api.routes import utils
from app.core.config import REPO_ROOT, Settings
from app.main import create_app


def test_api_route_contract_is_exact() -> None:
    schema = create_app(settings=_code_settings()).openapi()
    routes = {
        (method.upper(), path)
        for path, operations in schema["paths"].items()
        for method in operations
        if method in {"get", "post", "put", "delete", "patch"}
    }
    health = cast(APIRoute, utils.router.routes[0])
    assert health.methods is not None
    routes.update((method, f"/api/v1/utils{health.path}") for method in health.methods)
    assert routes == {
        ("GET", "/api/v1/users/me"),
        ("GET", "/api/v1/items/"),
        ("GET", "/api/v1/items/{id}"),
        ("POST", "/api/v1/items/"),
        ("PUT", "/api/v1/items/{id}"),
        ("DELETE", "/api/v1/items/{id}"),
        ("GET", "/api/v1/utils/health-check/"),
    }


def test_compose_has_only_backing_auth_services_and_a_digest_pinned_proxy() -> None:
    compose_path = Path(REPO_ROOT, "docker-compose.yml")
    text = compose_path.read_text()
    services_text = text.split("services:\n", 1)[1].split("\nvolumes:\n", 1)[0]
    assert set(re.findall(r"^  ([a-z0-9-]+):$", services_text, re.MULTILINE)) == {
        "db",
        "adminer",
        "dex",
        "oauth2-proxy",
    }
    dex_image = re.search(
        r"^    image: (dexidp/dex[^\n]+)$", services_text, re.MULTILINE
    )
    assert dex_image is not None
    assert re.fullmatch(
        r"dexidp/dex:v2\.45\.1-distroless@sha256:[0-9a-f]{64}",
        dex_image.group(1),
    )
    image = re.search(
        r"^    image: (quay\.io/oauth2-proxy/[^\n]+)$", services_text, re.MULTILINE
    )
    assert image is not None
    assert re.fullmatch(
        r"quay\.io/oauth2-proxy/oauth2-proxy:v7\.15\.3@sha256:[0-9a-f]{64}",
        image.group(1),
    )
    assert "--cookie-samesite=lax" in services_text
    assert "--insecure-oidc-skip-nonce=false" in services_text
    assert "--code-challenge-method=S256" in services_text
    assert "--pass-authorization-header=false" in services_text
    assert "--upstream=http://${DEV_PROXY_UPSTREAM_HOST" in services_text
    assert "${DEV_PROXY_EXTRA_HOST_MAPPING" in services_text
    assert "- host.docker.internal:host-gateway" not in services_text
    assert "lokal-token-printer" not in text


def _code_settings() -> Settings:
    return Settings(  # type: ignore[call-arg]
        _env_file=None,
        PROJECT_NAME="route contract",
        POSTGRES_SERVER="localhost",
        POSTGRES_USER="postgres",
        POSTGRES_PASSWORD="route-contract-database-password",
        POSTGRES_DB="test",
        OAUTH2_PROXY_UPSTREAM_PASSWORD="route-contract-upstream-password-0123456789",
    )
