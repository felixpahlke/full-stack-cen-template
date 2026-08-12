import os
import shutil
import signal
import socket
import subprocess
import sys
import time
import uuid
from collections.abc import Generator
from pathlib import Path
from urllib.error import URLError
from urllib.request import urlopen

import pytest
from alembic.config import Config
from alembic.script import ScriptDirectory
from sqlalchemy import create_engine, make_url, text

from app.core.config import BACKEND_ROOT
from app.startup import MIGRATION_LOCK_KEY


@pytest.fixture
def empty_database_url(database_url: str) -> Generator[str, None, None]:
    source_url = make_url(database_url)
    database_name = f"startup_test_{uuid.uuid4().hex}"
    admin_engine = create_engine(
        source_url.set(database="postgres"), isolation_level="AUTOCOMMIT"
    )
    with admin_engine.connect() as connection:
        connection.execute(text(f'CREATE DATABASE "{database_name}"'))

    try:
        yield source_url.set(database=database_name).render_as_string(
            hide_password=False
        )
    finally:
        with admin_engine.connect() as connection:
            connection.execute(
                text(
                    "SELECT pg_terminate_backend(pid) FROM pg_stat_activity "
                    "WHERE datname = :database AND pid <> pg_backend_pid()"
                ),
                {"database": database_name},
            )
            connection.execute(text(f'DROP DATABASE "{database_name}"'))
        admin_engine.dispose()


def _expected_heads(config: Config | None = None) -> set[str]:
    alembic_config = config or Config(str(BACKEND_ROOT / "alembic.ini"))
    return set(ScriptDirectory.from_config(alembic_config).get_heads())


def _startup_env(
    database_url: str,
    *,
    migrate: bool = True,
    lock_timeout: float = 60,
) -> dict[str, str]:
    url = make_url(database_url)
    return {
        **os.environ,
        "PYTHONPATH": str(BACKEND_ROOT),
        "PYTHONUNBUFFERED": "1",
        "ENVIRONMENT": "production",
        "LOG_LEVEL": "INFO",
        "PROJECT_NAME": "Migration startup test",
        "SECRET_KEY": "migration-startup-test-secret-at-least-32-bytes",
        "POSTGRES_SERVER": url.host or "localhost",
        "POSTGRES_PORT": str(url.port or 5432),
        "POSTGRES_USER": url.username or "postgres",
        "POSTGRES_PASSWORD": url.password or "",
        "POSTGRES_DB": url.database or "startup_test",
        "OAUTH2_PROXY_UPSTREAM_PASSWORD": "migration-startup-upstream-password",
        "MIGRATE_ON_START": str(migrate).lower(),
        "MIGRATION_LOCK_TIMEOUT_SECONDS": str(lock_timeout),
    }


def _start_process(
    command: list[str], env: dict[str, str], log_path: Path
) -> tuple[subprocess.Popen[str], object]:
    stream = log_path.open("w")
    process = subprocess.Popen(
        command,
        cwd=BACKEND_ROOT,
        env=env,
        stdout=stream,
        stderr=subprocess.STDOUT,
        text=True,
        start_new_session=True,
    )
    return process, stream


def _stop_process(process: subprocess.Popen[str], stream: object) -> None:
    if process.poll() is None:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=15)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=10)
    stream.close()  # type: ignore[attr-defined]


def _wait_for_logs(
    paths: list[Path], phrase: str, count: int, timeout: float = 30
) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if sum(path.read_text().count(phrase) for path in paths) >= count:
            return
        time.sleep(0.05)
    pytest.fail(
        f"Timed out waiting for {count} occurrences of {phrase!r}:\n"
        + "\n".join(path.read_text() for path in paths)
    )


def _free_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
        assert isinstance(port, int)
        return port


def _wait_for_health(port: int, timeout: float = 60) -> None:
    deadline = time.monotonic() + timeout
    last_error: OSError | None = None
    while time.monotonic() < deadline:
        try:
            with urlopen(
                f"http://127.0.0.1:{port}/api/v1/utils/health-check/", timeout=2
            ) as response:
                if response.status == 200:
                    return
        except OSError as error:
            last_error = error
        time.sleep(0.1)
    pytest.fail(f"Server on port {port} did not become healthy: {last_error}")


def _server_command(port: int) -> list[str]:
    return [
        sys.executable,
        "-m",
        "uvicorn",
        "app.main:create_app",
        "--factory",
        "--host",
        "127.0.0.1",
        "--port",
        str(port),
    ]


def _run_startup(
    database_url: str,
    *,
    migrate: bool = True,
    lock_timeout: float = 60,
) -> subprocess.CompletedProcess[str]:
    command = [sys.executable, "-m", "app.startup"]
    return subprocess.run(
        command,
        cwd=BACKEND_ROOT,
        env=_startup_env(database_url, migrate=migrate, lock_timeout=lock_timeout),
        capture_output=True,
        text=True,
        timeout=60,
        check=False,
    )


def _assert_database_ready(database_url: str) -> None:
    engine = create_engine(database_url)
    try:
        with engine.connect() as connection:
            current = {
                connection.scalar(text("SELECT version_num FROM alembic_version"))
            }
            assert current == _expected_heads()
            assert connection.scalar(text("SELECT count(*) FROM item")) == 0
    finally:
        engine.dispose()


def test_three_replicas_serialize_migrate_seed_and_become_ready(
    empty_database_url: str, tmp_path: Path
) -> None:
    engine = create_engine(empty_database_url)
    lock_connection = engine.connect()
    lock_connection.execute(
        text("SELECT pg_advisory_lock(:key)"), {"key": MIGRATION_LOCK_KEY}
    )
    lock_connection.commit()

    entries: list[tuple[subprocess.Popen[str], object, Path, int]] = []
    try:
        for index in range(3):
            port = _free_port()
            path = tmp_path / f"replica-{index}.log"
            process, stream = _start_process(
                _server_command(port), _startup_env(empty_database_url), path
            )
            entries.append((process, stream, path, port))

        _wait_for_logs(
            [path for _process, _stream, path, _port in entries],
            "Database migration lock busy; waiting",
            3,
        )
        lock_connection.execute(
            text("SELECT pg_advisory_unlock(:key)"), {"key": MIGRATION_LOCK_KEY}
        )
        lock_connection.commit()
        for _process, _stream, _path, port in entries:
            _wait_for_health(port)

        combined = "\n".join(path.read_text() for _, _, path, _ in entries)
        assert combined.count("Running Alembic migrations under database lock") == 1
        assert combined.count("Database startup completed successfully") == 3
        assert all(process.poll() is None for process, _, _, _ in entries)
        _assert_database_ready(empty_database_url)
    finally:
        if not lock_connection.closed:
            lock_connection.close()
        engine.dispose()
        for process, stream, _path, _port in entries:
            _stop_process(process, stream)


def test_restart_is_noop_and_migrate_disabled_current_schema_serves(
    empty_database_url: str, tmp_path: Path
) -> None:
    first = _run_startup(empty_database_url)
    assert first.returncode == 0, first.stdout + first.stderr

    restart_port = _free_port()
    restart_path = tmp_path / "restart.log"
    restart, restart_stream = _start_process(
        _server_command(restart_port), _startup_env(empty_database_url), restart_path
    )
    try:
        _wait_for_health(restart_port)
        restart_output = restart_path.read_text()
        assert "Database schema already at bundled Alembic head" in restart_output
        assert "Running Alembic migrations" not in restart_output
    finally:
        _stop_process(restart, restart_stream)

    port = _free_port()
    path = tmp_path / "restart-opt-out.log"
    process, stream = _start_process(
        _server_command(port),
        _startup_env(empty_database_url, migrate=False),
        path,
    )
    try:
        _wait_for_health(port)
        output = path.read_text()
        assert "MIGRATE_ON_START=false; verifying database revision" in output
        assert "Running Alembic migrations" not in output
        _assert_database_ready(empty_database_url)
    finally:
        _stop_process(process, stream)


def test_migrate_disabled_stale_schema_refuses_readiness(
    empty_database_url: str, tmp_path: Path
) -> None:
    port = _free_port()
    path = tmp_path / "stale-opt-out.log"
    process, stream = _start_process(
        _server_command(port),
        _startup_env(empty_database_url, migrate=False),
        path,
    )
    try:
        process.wait(timeout=30)
        assert process.returncode != 0
        with pytest.raises(URLError):
            urlopen(f"http://127.0.0.1:{port}/api/v1/utils/health-check/", timeout=1)
        output = path.read_text()
        assert "Database schema revision does not match bundled Alembic head" in output
        assert "db_revision=[]" in output
        assert f"bundled_head={sorted(_expected_heads())}" in output
    finally:
        _stop_process(process, stream)


def test_broken_migration_fails_then_fixed_restart_succeeds(
    empty_database_url: str, tmp_path: Path
) -> None:
    script_dir = tmp_path / "alembic"
    shutil.copytree(BACKEND_ROOT / "app" / "alembic", script_dir)
    bundled_head = next(iter(_expected_heads()))
    (script_dir / "versions" / "broken_test_migration.py").write_text(
        'revision = "broken"\n'
        f'down_revision = "{bundled_head}"\n'
        "branch_labels = None\n"
        "depends_on = None\n\n"
        "from alembic import op\n\n"
        "def upgrade():\n"
        '    op.execute("SELECT deliberately_broken(")\n\n'
        "def downgrade():\n"
        "    pass\n"
    )
    config_path = tmp_path / "broken-alembic.ini"
    config_path.write_text(f"[alembic]\nscript_location = {script_dir}\n")
    broken_port = _free_port()
    broken_code = f"""
from contextlib import asynccontextmanager
from alembic.config import Config
from fastapi import FastAPI
import uvicorn
from app.core.config import get_settings
from app.core.db import get_engine
from app.startup import initialize_database

config = Config({str(config_path)!r})
config.attributes["configure_logger"] = False

@asynccontextmanager
async def lifespan(_app):
    initialize_database(get_settings(), get_engine(), alembic_config=config)
    yield

app = FastAPI(lifespan=lifespan)
uvicorn.run(app, host="127.0.0.1", port={broken_port})
"""
    broken_path = tmp_path / "broken.log"
    broken, broken_stream = _start_process(
        [sys.executable, "-c", broken_code],
        _startup_env(empty_database_url),
        broken_path,
    )
    try:
        broken.wait(timeout=30)
        assert broken.returncode != 0
        with pytest.raises(URLError):
            urlopen(f"http://127.0.0.1:{broken_port}/", timeout=1)
        broken_output = broken_path.read_text()
        assert "Running Alembic migrations under database lock" in broken_output
        assert "deliberately_broken" in broken_output
    finally:
        _stop_process(broken, broken_stream)

    fixed_port = _free_port()
    fixed_path = tmp_path / "fixed.log"
    fixed, fixed_stream = _start_process(
        _server_command(fixed_port), _startup_env(empty_database_url), fixed_path
    )
    try:
        _wait_for_health(fixed_port)
        _assert_database_ready(empty_database_url)
    finally:
        _stop_process(fixed, fixed_stream)


def test_lock_wait_timeout_is_bounded_and_actionable(
    empty_database_url: str,
) -> None:
    engine = create_engine(empty_database_url)
    lock_connection = engine.connect()
    lock_connection.execute(
        text("SELECT pg_advisory_lock(:key)"), {"key": MIGRATION_LOCK_KEY}
    )
    lock_connection.commit()
    started = time.monotonic()
    try:
        result = _run_startup(empty_database_url, lock_timeout=0.2)
    finally:
        lock_connection.close()
        engine.dispose()

    assert result.returncode != 0
    assert time.monotonic() - started < 5
    assert "Timed out after 0.2 seconds" in result.stderr
    assert "Inspect pg_stat_activity and resolve the lock owner" in result.stderr
    assert "Running Alembic migrations" not in result.stderr
