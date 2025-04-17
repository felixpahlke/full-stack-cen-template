from fastapi import APIRouter

from app.api.deps import APIKeyDep
from app.api.routes import example, utils

unsecured_api_router = APIRouter()
unsecured_api_router.include_router(utils.router, prefix="/utils", tags=["utils"])

secured_api_router = APIRouter(dependencies=[APIKeyDep])
secured_api_router.include_router(
    example.router,
    prefix="/example",
    tags=["example"],
)

api_router = APIRouter()
api_router.include_router(unsecured_api_router)
api_router.include_router(secured_api_router)
