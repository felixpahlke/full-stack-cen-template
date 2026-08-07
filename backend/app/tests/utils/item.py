from sqlmodel import Session

from app import crud
from app.models import ItemCreate
from app.tables import Item
from app.tests.utils.utils import random_lower_string


def create_random_item(db: Session) -> Item:
    title = random_lower_string()
    description = random_lower_string()
    item_in = ItemCreate(title=title, description=description)
    return crud.create_item(session=db, item_in=item_in)
