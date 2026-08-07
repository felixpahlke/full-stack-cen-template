import argparse
import json
from pathlib import Path
from typing import Any

from pydantic_settings import PydanticBaseSettingsSource

from app.core.config import REPO_ROOT, Settings
from app.main import create_app


class CodegenSettings(Settings):
    @classmethod
    def settings_customise_sources(
        cls,
        settings_cls: type[Settings],
        init_settings: PydanticBaseSettingsSource,
        env_settings: PydanticBaseSettingsSource,
        dotenv_settings: PydanticBaseSettingsSource,
        file_secret_settings: PydanticBaseSettingsSource,
    ) -> tuple[PydanticBaseSettingsSource, ...]:
        del cls, settings_cls, env_settings, dotenv_settings, file_secret_settings
        return (init_settings,)


def normalize_operation_ids(schema: dict[str, Any]) -> None:
    for path in schema["paths"].values():
        for operation in path.values():
            if not isinstance(operation, dict) or not operation.get("tags"):
                continue
            prefix = f"{operation['tags'][0]}-"
            operation_id = operation.get("operationId", "")
            if operation_id.startswith(prefix):
                operation["operationId"] = operation_id.removeprefix(prefix)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(REPO_ROOT, "frontend", "openapi.json"),
    )
    args = parser.parse_args()

    settings = CodegenSettings(
        PROJECT_NAME="Full Stack FastAPI Project",
        SECRET_KEY="codegen-only-secret",
        POSTGRES_SERVER="localhost",
        POSTGRES_USER="postgres",
        POSTGRES_PASSWORD="codegen-only-password",
        POSTGRES_DB="app",
        FIRST_SUPERUSER="codegen@example.com",
        FIRST_SUPERUSER_PASSWORD="codegen-only-password",
    )
    schema = create_app(settings=settings).openapi()
    normalize_operation_ids(schema)

    args.output.write_text(f"{json.dumps(schema, indent=2)}\n", encoding="utf-8")


if __name__ == "__main__":
    main()
