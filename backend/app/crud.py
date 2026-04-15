import uuid
from typing import Any

from sqlmodel import Session, select

from app.core.logger import get_logger, log_exception
from app.core.security import get_password_hash, verify_password
from app.models import ItemCreate, UserCreate, UserUpdate
from app.tables import Item, User

logger = get_logger(__name__)


def create_user(*, session: Session, user_create: UserCreate) -> User:
    try:
        logger.debug(f"Creating new user with email: {user_create.email}")
        db_obj = User.model_validate(
            user_create,
            update={"hashed_password": get_password_hash(user_create.password)},
        )
        session.add(db_obj)
        session.commit()
        session.refresh(db_obj)
        logger.debug(f"Successfully created user with ID: {db_obj.id}")
        return db_obj
    except Exception as e:
        log_exception(
            logger, e, context=f"Failed to create user with email: {user_create.email}"
        )
        raise


def update_user(*, session: Session, db_user: User, user_in: UserUpdate) -> Any:
    try:
        logger.debug(f"Updating user with ID: {db_user.id}")
        user_data = user_in.model_dump(exclude_unset=True)
        extra_data = {}
        if "password" in user_data:
            password = user_data["password"]
            hashed_password = get_password_hash(password)
            extra_data["hashed_password"] = hashed_password
        db_user.sqlmodel_update(user_data, update=extra_data)
        session.add(db_user)
        session.commit()
        session.refresh(db_user)
        logger.debug(f"Successfully updated user with ID: {db_user.id}")
        return db_user
    except Exception as e:
        log_exception(logger, e, context=f"Failed to update user with ID: {db_user.id}")
        raise


def get_user_by_email(*, session: Session, email: str) -> User | None:
    try:
        logger.debug(f"Fetching user by email: {email}")
        statement = select(User).where(User.email == email)
        session_user = session.exec(statement).first()
        if session_user:
            logger.debug(f"Found user with email: {email}")
        else:
            logger.debug(f"No user found with email: {email}")
        return session_user
    except Exception as e:
        log_exception(logger, e, context=f"Failed to fetch user by email: {email}")
        raise


def authenticate(*, session: Session, email: str, password: str) -> User | None:
    try:
        logger.debug(f"Authenticating user with email: {email}")
        db_user = get_user_by_email(session=session, email=email)
        if not db_user:
            logger.warning(f"Authentication failed: User not found with email: {email}")
            return None
        if not verify_password(password, db_user.hashed_password):
            logger.warning(
                f"Authentication failed: Invalid password for email: {email}"
            )
            return None
        logger.debug(f"Successfully authenticated user with email: {email}")
        return db_user
    except Exception as e:
        log_exception(
            logger, e, context=f"Failed to authenticate user with email: {email}"
        )
        raise


def create_item(*, session: Session, item_in: ItemCreate, owner_id: uuid.UUID) -> Item:
    try:
        logger.debug(f"Creating new item for owner_id: {owner_id}")
        db_item = Item.model_validate(item_in, update={"owner_id": owner_id})
        session.add(db_item)
        session.commit()
        session.refresh(db_item)
        logger.debug(f"Successfully created item with ID: {db_item.id}")
        return db_item
    except Exception as e:
        log_exception(
            logger, e, context=f"Failed to create item for owner_id: {owner_id}"
        )
        raise
