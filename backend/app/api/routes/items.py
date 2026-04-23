import uuid
from math import log
from typing import Any

from fastapi import APIRouter, HTTPException
from sqlmodel import func, select

from app.api.deps import CurrentUser, SessionDep
from app.core.logger import get_logger, log_exception
from app.models import ItemCreate, ItemPublic, ItemsPublic, ItemUpdate, Message
from app.tables import Item

logger = get_logger(__name__)

router = APIRouter()


@router.get("/", response_model=ItemsPublic)
def read_items(
    session: SessionDep, current_user: CurrentUser, skip: int = 0, limit: int = 100
) -> Any:
    """
    Retrieve items.
    """
    logger.debug(
        f"User {current_user.id} retrieving items (skip={skip}, limit={limit})"
    )

    if current_user.is_superuser:
        count_statement = select(func.count()).select_from(Item)
        count = session.exec(count_statement).one()
        statement = select(Item).offset(skip).limit(limit)
        items = session.exec(statement).all()
    else:
        count_statement = (
            select(func.count())
            .select_from(Item)
            .where(Item.owner_id == current_user.id)
        )
        count = session.exec(count_statement).one()
        statement = (
            select(Item)
            .where(Item.owner_id == current_user.id)
            .offset(skip)
            .limit(limit)
        )
        items = session.exec(statement).all()

    logger.debug(f"Successfully retrieved {count} items for user {current_user.id}")
    return ItemsPublic(data=items, count=count)


@router.get("/{id}", response_model=ItemPublic)
def read_item(session: SessionDep, current_user: CurrentUser, id: uuid.UUID) -> Any:
    """
    Get item by ID.
    """
    logger.debug(f"User {current_user.id} retrieving item {id}")
    item = session.get(Item, id)
    if not item:
        logger.warning(f"Item {id} not found for user {current_user.id}")
        raise HTTPException(status_code=404, detail="Item not found")
    if not current_user.is_superuser and (item.owner_id != current_user.id):
        logger.warning(
            f"User {current_user.id} attempted to access item {id} without permission"
        )
        raise HTTPException(status_code=400, detail="Not enough permissions")
    logger.debug(f"Successfully retrieved item {id} for user {current_user.id}")
    return item


@router.post("/", response_model=ItemPublic)
def create_item(
    *, session: SessionDep, current_user: CurrentUser, item_in: ItemCreate
) -> Any:
    """
    Create new item.
    """
    logger.debug(f"User {current_user.id} creating new item: {item_in.title}")
    item = Item.model_validate(item_in, update={"owner_id": current_user.id})
    session.add(item)
    session.commit()
    session.refresh(item)
    logger.debug(f"Successfully created item {item.id} for user {current_user.id}")
    return item


@router.put("/{id}", response_model=ItemPublic)
def update_item(
    *,
    session: SessionDep,
    current_user: CurrentUser,
    id: uuid.UUID,
    item_in: ItemUpdate,
) -> Any:
    """
    Update an item.
    """
    logger.debug(f"User {current_user.id} updating item {id}")
    item = session.get(Item, id)
    if not item:
        logger.warning(f"Item {id} not found for update by user {current_user.id}")
        raise HTTPException(status_code=404, detail="Item not found")
    if not current_user.is_superuser and (item.owner_id != current_user.id):
        logger.warning(
            f"User {current_user.id} attempted to update item {id} without permission"
        )
        raise HTTPException(status_code=400, detail="Not enough permissions")
    update_dict = item_in.model_dump(exclude_unset=True)
    item.sqlmodel_update(update_dict)
    session.add(item)
    session.commit()
    session.refresh(item)
    logger.debug(f"Successfully updated item {id} for user {current_user.id}")
    return item


@router.delete("/{id}")
def delete_item(
    session: SessionDep, current_user: CurrentUser, id: uuid.UUID
) -> Message:
    """
    Delete an item.
    """
    logger.debug(f"User {current_user.id} deleting item {id}")
    item = session.get(Item, id)
    if not item:
        logger.warning(f"Item {id} not found for deletion by user {current_user.id}")
        raise HTTPException(status_code=404, detail="Item not found")
    if not current_user.is_superuser and (item.owner_id != current_user.id):
        logger.warning(
            f"User {current_user.id} attempted to delete item {id} without permission"
        )
        raise HTTPException(status_code=400, detail="Not enough permissions")
    session.delete(item)
    session.commit()
    logger.debug(f"Successfully deleted item {id} for user {current_user.id}")
    return Message(message="Item deleted successfully")
