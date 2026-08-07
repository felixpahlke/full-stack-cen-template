from collections.abc import Generator
from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import APIKeyHeader
from sqlalchemy import Engine
from sqlmodel import Session

from app.core.config import Settings, get_settings
from app.core.db import get_engine

api_key_header = APIKeyHeader(name="X-API-Key")


def get_db(
    engine: Annotated[Engine, Depends(get_engine)],
) -> Generator[Session, None, None]:
    with Session(engine) as session:
        yield session


SettingsDep = Annotated[Settings, Depends(get_settings)]
SessionDep = Annotated[Session, Depends(get_db)]


async def verify_api_key(
    settings: SettingsDep, api_key: str = Depends(api_key_header)
) -> None:
    if api_key != settings.API_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key",
        )


APIKeyDep = Depends(verify_api_key)
