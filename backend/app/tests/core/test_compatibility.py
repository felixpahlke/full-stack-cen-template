import logging
from datetime import timedelta

import jwt
import pytest

import app.core.logger as logger_module
import app.core.security as security_module
from app.core.config import LogLevel


class CompatibilitySettings:
    EFFECTIVE_LOG_LEVEL = LogLevel.WARNING
    SECRET_KEY = "compatibility-test-secret-at-least-32-bytes"


def test_setup_logging_uses_environment_derived_default(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(logger_module, "get_settings", CompatibilitySettings)

    logger_module.setup_logging()

    assert logging.getLogger().level == logging.WARNING


def test_create_access_token_keeps_legacy_two_argument_call(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(security_module, "get_settings", CompatibilitySettings)

    token = security_module.create_access_token("subject", timedelta(minutes=5))

    payload = jwt.decode(token, CompatibilitySettings.SECRET_KEY, algorithms=["HS256"])
    assert payload["sub"] == "subject"
