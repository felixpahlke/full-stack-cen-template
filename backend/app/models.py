from sqlmodel import SQLModel


class HelloWorld(SQLModel):
    message: str
