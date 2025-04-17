from fastapi import APIRouter

from app.models import HelloWorld

router = APIRouter()


@router.get("/hello", response_model=HelloWorld)
def hello_world() -> HelloWorld:
    """
    Retrieve items.
    """
    return HelloWorld(message="Hello, World!")
