from functools import lru_cache

from sqlalchemy import Engine
from sqlmodel import Session, create_engine, select

from app import crud
from app.core.config import Settings, get_settings
from app.models import UserCreate
from app.tables import User


def create_db_engine(database_url: str) -> Engine:
    return create_engine(database_url)


@lru_cache
def get_engine() -> Engine:
    return create_db_engine(str(get_settings().SQLALCHEMY_DATABASE_URI))


# make sure all SQLModel models are imported (app.tables) before initializing DB
# otherwise, SQLModel might fail to initialize relationships properly
# for more details: https://github.com/fastapi/full-stack-fastapi-template/issues/28


def init_db(session: Session, settings: Settings) -> None:
    # Tables should be created with Alembic migrations
    # But if you don't want to use migrations, create
    # the tables un-commenting the next lines
    # from sqlmodel import SQLModel

    # This works because the models are already imported and registered from app.tables
    # SQLModel.metadata.create_all(session.get_bind())

    user = session.exec(
        select(User).where(User.email == settings.FIRST_SUPERUSER)
    ).first()
    if not user:
        user_in = UserCreate(
            email=settings.FIRST_SUPERUSER,
            password=settings.FIRST_SUPERUSER_PASSWORD,
            is_superuser=True,
        )
        user = crud.create_user(session=session, user_create=user_in)
