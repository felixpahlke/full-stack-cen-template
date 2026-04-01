import json
import logging

import httpx

FLAVOR = "backend-only"
TRACKING_DOMAIN = "team-flavors"
TRACKING_ENDPOINT = "https://plausible-plausible.ce-oc-dev-cluster-e35fa0051812cc24b064c01c5a512ff2-0000.eu-de.containers.appdomain.cloud/api/event"
logger = logging.getLogger(__name__)


def get_host_kind(environment: str) -> str:
    if environment == "local":
        return "local"
    return "remote"


def get_tracking_url(environment: str) -> str:
    if environment == "local":
        return f"http://localhost/{FLAVOR}"
    return f"https://{FLAVOR}"


def build_flavor_event_body(
    *,
    environment: str,
) -> str:
    host_kind = get_host_kind(environment)
    body = {
        "n": "Flavor Used",
        "d": TRACKING_DOMAIN,
        "u": get_tracking_url(environment),
        "p": {
            "app_flavor": FLAVOR,
            "environment": environment,
            "host_kind": host_kind,
            "tracking_source": "backend",
        },
    }
    return json.dumps(body)


async def send_flavor_tracking_event(
    *,
    environment: str,
) -> None:
    body = build_flavor_event_body(environment=environment)

    try:
        async with httpx.AsyncClient(timeout=2.0) as client:
            await client.post(
                TRACKING_ENDPOINT,
                headers={"Content-Type": "text/plain"},
                content=body,
            )
    except httpx.HTTPError as exc:
        logger.warning("Flavor tracking failed: %s", exc)
