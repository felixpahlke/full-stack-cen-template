from fastapi import APIRouter

from app.models import HelloWorld

router = APIRouter()


@router.get("/hello", response_model=HelloWorld)
def hello_world() -> HelloWorld:
    """Return the example greeting."""
    return HelloWorld(message="Hello, World!")
