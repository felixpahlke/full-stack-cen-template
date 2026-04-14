from datetime import timedelta
from typing import Annotated, Any

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import OAuth2PasswordRequestForm

from app import crud
from app.api.deps import CurrentUser, SessionDep
from app.core import security
from app.core.config import settings
from app.core.logger import get_logger, log_exception
from app.models import Token, UserPublic

router = APIRouter()
logger = get_logger(__name__)


@router.post("/login/access-token")
def login_access_token(
    session: SessionDep, form_data: Annotated[OAuth2PasswordRequestForm, Depends()]
) -> Token:
    """
    OAuth2 compatible token login, get an access token for future requests
    """
    try:
        logger.info(f"Login attempt for email: {form_data.username}")
        user = crud.authenticate(
            session=session, email=form_data.username, password=form_data.password
        )
        if not user:
            logger.warning(
                f"Login failed for email: {form_data.username} - Invalid credentials"
            )
            raise HTTPException(status_code=400, detail="Incorrect email or password")
        elif not user.is_active:
            logger.warning(
                f"Login failed for email: {form_data.username} - Inactive user"
            )
            raise HTTPException(status_code=400, detail="Inactive user")
        access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
        logger.info(f"Successfully logged in user: {form_data.username}")
        return Token(
            access_token=security.create_access_token(
                user.id, expires_delta=access_token_expires
            )
        )
    except HTTPException:
        raise
    except Exception as e:
        log_exception(
            logger, e, context=f"Login failed for email: {form_data.username}"
        )
        raise


@router.post("/login/test-token", response_model=UserPublic)
def test_token(current_user: CurrentUser) -> Any:
    """
    Test access token
    """
    logger.info(f"Token test for user: {current_user.id}")
    return current_user
