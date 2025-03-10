from collections.abc import Generator
from typing import Annotated

import jwt
import requests
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer
from jwt import PyJWKClient
from sqlmodel import Session

from app.core.config import settings
from app.core.db import engine
from app.core.singleton import Singleton
from app.models import TokenPayload, User


def get_db() -> Generator[Session, None, None]:
    with Session(engine) as session:
        yield session


bearer = HTTPBearer()

SessionDep = Annotated[Session, Depends(get_db)]

TokenDep = Annotated[str, Depends(bearer)]


@Singleton
class JWKSUrlClient:
    pyjwk_client: PyJWKClient | None = None

    def __init__(self):
        openid_config = requests.get(settings.OAUTH2_PROXY_WELL_KNOWN_URL)
        openid_config.raise_for_status()
        self.pyjwk_client = PyJWKClient(openid_config.json()["jwks_uri"])


def get_current_user(token: TokenDep) -> User:
    token = token.credentials

    try:
        jwks_client = JWKSUrlClient.instance()
        signing_key = jwks_client.pyjwk_client.get_signing_key_from_jwt(token)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Failed to get signing key: {str(e)}",
        )

    try:
        data: TokenPayload = jwt.decode(
            token,
            signing_key,
            issuer=settings.OAUTH2_PROXY_OIDC_ISSUER_URL,
            options={"verify_aud": False, "verify_exp": False},
            algorithms=["RS256"],
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Failed to decode token: {str(e)}",
        )

    # Note: There is more data in the token, but we only use the id, email and name currently
    user = User(id=data["sub"], email=data["email"], name=data["name"])

    return user


CurrentUser = Annotated[User, Depends(get_current_user)]
