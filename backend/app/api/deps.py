from collections.abc import Generator
from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import APIKeyHeader
from sqlmodel import Session

from app.core.config import settings
from app.core.db import engine

api_key_header = APIKeyHeader(name="X-API-Key")


def get_db() -> Generator[Session, None, None]:
    with Session(engine) as session:
        yield session


SessionDep = Annotated[Session, Depends(get_db)]


async def verify_api_key(api_key: str = Depends(api_key_header)) -> None:
    if api_key != settings.API_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key",
        )


APIKeyDep = Depends(verify_api_key)
