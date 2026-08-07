from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import APIKeyHeader

from app.core.config import Settings, get_settings

api_key_header = APIKeyHeader(name="X-API-Key")
APIKeyHeaderDep = Annotated[str, Depends(api_key_header)]
SettingsDep = Annotated[Settings, Depends(get_settings)]


async def verify_api_key(api_key: APIKeyHeaderDep, settings: SettingsDep) -> None:
    if api_key != settings.API_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key",
        )


APIKeyDep = Depends(verify_api_key)
