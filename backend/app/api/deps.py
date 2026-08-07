from base64 import b64decode
from binascii import Error as Base64Error
from collections import Counter
from collections.abc import Generator
from secrets import compare_digest
from typing import Annotated

from fastapi import Depends, HTTPException, Request, status
from pydantic import ValidationError
from sqlalchemy import Engine
from sqlmodel import Session

from app.core.config import Settings, get_settings
from app.core.db import get_engine
from app.models import User

IDENTITY_HEADERS = {
    b"x-forwarded-user",
    b"x-forwarded-email",
    b"x-forwarded-preferred-username",
}
PROTECTED_HEADERS = IDENTITY_HEADERS | {b"authorization"}


def get_db(
    engine: Annotated[Engine, Depends(get_engine)],
) -> Generator[Session, None, None]:
    with Session(engine) as session:
        yield session


SettingsDep = Annotated[Settings, Depends(get_settings)]
SessionDep = Annotated[Session, Depends(get_db)]


def get_current_user(request: Request, settings: SettingsDep) -> User:
    if not _has_unambiguous_proxy_headers(request):
        raise _unauthorized()
    if not _has_proxy_credential(request, settings):
        raise _unauthorized()

    subject = (request.headers.get("x-forwarded-user") or "").strip()
    email = (request.headers.get("x-forwarded-email") or "").strip().lower()
    name = (request.headers.get("x-forwarded-preferred-username") or email).strip()
    if not subject or not email or "," in subject or "," in email:
        raise _unauthorized()
    try:
        return User(id=subject, email=email, name=name or email)
    except ValidationError:
        raise _unauthorized() from None


def _has_unambiguous_proxy_headers(request: Request) -> bool:
    counts: Counter[bytes] = Counter()
    for raw_name, _ in request.scope.get("headers", []):
        lowered = raw_name.lower()
        normalized = lowered.replace(b"_", b"-")
        if normalized not in PROTECTED_HEADERS:
            continue
        if lowered != normalized:
            return False
        counts[normalized] += 1
    return (
        counts[b"authorization"] == 1
        and counts[b"x-forwarded-user"] == 1
        and counts[b"x-forwarded-email"] == 1
        and counts[b"x-forwarded-preferred-username"] <= 1
    )


def _has_proxy_credential(request: Request, settings: Settings) -> bool:
    authorization = request.headers.get("authorization") or ""
    scheme, _, encoded = authorization.partition(" ")
    if scheme.lower() != "basic" or not encoded:
        return False
    try:
        credentials = b64decode(encoded, validate=True).decode()
    except (Base64Error, UnicodeDecodeError):
        return False
    _, separator, password = credentials.partition(":")
    return bool(separator) and compare_digest(
        password, settings.OAUTH2_PROXY_UPSTREAM_PASSWORD
    )


def _unauthorized() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Not authenticated",
    )


CurrentUser = Annotated[User, Depends(get_current_user)]
