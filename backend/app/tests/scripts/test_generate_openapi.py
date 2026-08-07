import os
import subprocess
import sys
from pathlib import Path

from app.core.config import REPO_ROOT


def generate_openapi(output: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            sys.executable,
            "backend/scripts/generate_openapi.py",
            "--output",
            str(output),
        ],
        cwd=REPO_ROOT,
        env={
            "PATH": os.environ["PATH"],
            "PYTHONPATH": str(REPO_ROOT / "backend"),
            "ENVIRONMENT": "production",
            "POSTGRES_PORT": "not-a-number",
        },
        capture_output=True,
        text=True,
        check=False,
    )


def test_openapi_generation_is_deterministic(tmp_path: Path) -> None:
    first = tmp_path / "first.json"
    second = tmp_path / "second.json"

    first_result = generate_openapi(first)
    second_result = generate_openapi(second)

    assert first_result.returncode == 0, first_result.stderr
    assert second_result.returncode == 0, second_result.stderr
    assert first.read_bytes() == second.read_bytes()
