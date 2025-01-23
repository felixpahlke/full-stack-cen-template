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
from app.schemas import TokenPayload, User

bearer = HTTPBearer()


def get_db() -> Generator[Session, None, None]:
    with Session(engine) as session:
        yield session


SessionDep = Annotated[Session, Depends(get_db)]

TokenDep = Annotated[str, Depends(bearer)]


class JWKSUrlManager:
    _instance = None
    _jwks_url = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def get_jwks_url(self) -> str:
        if self._jwks_url is None:
            openid_config = requests.get(settings.OAUTH2_PROXY_WELL_KNOWN_URL)
            openid_config.raise_for_status()
            self._jwks_url = openid_config.json()["jwks_uri"]
        return self._jwks_url


def get_jwks_url() -> str:
    return JWKSUrlManager().get_jwks_url()


JWKSUrl = Annotated[str, Depends(get_jwks_url)]


def get_current_user(token: TokenDep, jwks_url: JWKSUrl) -> User:
    token = token.credentials

    # Fetch JWKS URL from the OpenID Configuration endpoint

    jwks_client = PyJWKClient(jwks_url)
    signing_key = jwks_client.get_signing_key_from_jwt(token)

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
