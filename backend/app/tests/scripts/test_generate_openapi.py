import json
import os
import subprocess
import sys
from pathlib import Path

from app.core.config import REPO_ROOT


def generate_openapi(
    output: Path, *, api_prefix: str | None = None
) -> subprocess.CompletedProcess[str]:
    environment = {
        "PATH": os.environ["PATH"],
        "PYTHONPATH": str(REPO_ROOT / "backend"),
        "ENVIRONMENT": "production",
        "POSTGRES_PORT": "not-a-number",
        "OAUTH2_PROXY_UPSTREAM_PASSWORD": "host-value-must-not-leak",
    }
    if api_prefix is not None:
        environment["API_V1_STR"] = api_prefix
    return subprocess.run(
        [
            sys.executable,
            "backend/scripts/generate_openapi.py",
            "--output",
            str(output),
        ],
        cwd=REPO_ROOT,
        env=environment,
        capture_output=True,
        text=True,
        check=False,
    )


def test_openapi_generation_is_offline_deterministic_and_uses_string_owner(
    tmp_path: Path,
) -> None:
    first = tmp_path / "first.json"
    second = tmp_path / "second.json"
    first_result = generate_openapi(first)
    second_result = generate_openapi(second)
    assert first_result.returncode == 0, first_result.stderr
    assert second_result.returncode == 0, second_result.stderr
    assert first.read_bytes() == second.read_bytes()
    schema = json.loads(first.read_text())
    assert schema["components"]["schemas"]["ItemPublic"]["properties"]["owner_id"] == {
        "type": "string",
        "title": "Owner Id",
    }
    assert len(schema["paths"]) == 3


def test_openapi_generation_honors_api_prefix_without_other_settings(
    tmp_path: Path,
) -> None:
    output = tmp_path / "custom.json"
    result = generate_openapi(output, api_prefix="/custom")
    assert result.returncode == 0, result.stderr
    schema = json.loads(output.read_text())
    assert "/custom/users/me" in schema["paths"]
    assert "/custom/items/" in schema["paths"]
