from typing import Any

from fastapi import APIRouter

from app.api.deps import CurrentUser
from app.schemas import User

router = APIRouter()


@router.get("/me", response_model=User)
def read_user_me(current_user: CurrentUser) -> Any:
    """
    Get current user.
    """
    return current_user
