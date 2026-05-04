import uuid
from datetime import datetime

from pydantic import EmailStr
from sqlmodel import Field, SQLModel

from app.tables import EmailStatus, ScanResult

# Users


class UserBase(SQLModel):
    email: EmailStr = Field(unique=True, index=True, max_length=255)
    is_active: bool = True
    is_superuser: bool = False
    full_name: str | None = Field(default=None, max_length=255)


# Properties to receive via API on creation
class UserCreate(UserBase):
    password: str = Field(min_length=8, max_length=40)


class UserRegister(SQLModel):
    email: EmailStr = Field(max_length=255)
    password: str = Field(min_length=8, max_length=40)
    full_name: str | None = Field(default=None, max_length=255)
    access_password: str | None = Field(default=None, max_length=255)


# Properties to receive via API on update, all are optional
class UserUpdate(UserBase):
    email: EmailStr | None = Field(default=None, max_length=255)  # type: ignore
    password: str | None = Field(default=None, min_length=8, max_length=40)


class UserUpdateMe(SQLModel):
    full_name: str | None = Field(default=None, max_length=255)
    email: EmailStr | None = Field(default=None, max_length=255)


class UpdatePassword(SQLModel):
    current_password: str = Field(min_length=8, max_length=40)
    new_password: str = Field(min_length=8, max_length=40)


class UserPublic(UserBase):
    id: uuid.UUID


class UsersPublic(SQLModel):
    data: list[UserPublic]
    count: int


# Items


class ItemBase(SQLModel):
    title: str = Field(min_length=1, max_length=255)
    description: str | None = Field(default=None, max_length=255)


# Properties to receive on item creation
class ItemCreate(ItemBase):
    pass


# Properties to receive on item update
class ItemUpdate(ItemBase):
    title: str | None = Field(default=None, min_length=1, max_length=255)  # type: ignore


class ItemPublic(ItemBase):
    id: uuid.UUID
    owner_id: uuid.UUID


class ItemsPublic(SQLModel):
    data: list[ItemPublic]
    count: int


# Tickets


class TicketBase(SQLModel):
    first_name: str = Field(max_length=255)
    last_name: str = Field(max_length=255)
    guest_email: str = Field(max_length=255)
    role: str | None = Field(default=None, max_length=255)
    host_email: str = Field(max_length=255)
    guest_age: str | None = Field(default=None, max_length=100)


class TicketCreate(TicketBase):
    pass


class TicketUpdate(SQLModel):
    first_name: str | None = Field(default=None, max_length=255)
    last_name: str | None = Field(default=None, max_length=255)
    guest_email: str | None = Field(default=None, max_length=255)
    role: str | None = Field(default=None, max_length=255)
    host_email: str | None = Field(default=None, max_length=255)
    guest_age: str | None = Field(default=None, max_length=100)


class TicketPublic(TicketBase):
    id: uuid.UUID
    qr_code_data: str
    is_scanned: bool
    scanned_at: datetime | None
    scanner_device_id: str | None
    scanner_user_id: str | None
    email_sent: bool
    email_sent_at: datetime | None
    email_delivery_status: EmailStatus
    email_retry_count: int
    created_at: datetime
    updated_at: datetime


class TicketsPublic(SQLModel):
    data: list[TicketPublic]
    count: int


# Scan Events


class ScanEventPublic(SQLModel):
    id: uuid.UUID
    ticket_id: uuid.UUID
    timestamp: datetime
    scanner_device_id: str
    scanner_user_id: str
    scan_result: ScanResult
    error_message: str | None
    network_latency_ms: int | None


class ScanEventsPublic(SQLModel):
    data: list[ScanEventPublic]
    count: int


# Email Queue


class EmailQueuePublic(SQLModel):
    id: uuid.UUID
    ticket_id: uuid.UUID
    recipient_email: str
    subject: str
    status: EmailStatus
    retry_count: int
    next_retry_at: datetime | None
    last_error: str | None
    created_at: datetime
    processed_at: datetime | None


## General


# Generic message
class Message(SQLModel):
    message: str


# JSON payload containing access token
class Token(SQLModel):
    access_token: str
    token_type: str = "bearer"


# Contents of JWT token
class TokenPayload(SQLModel):
    sub: str | None = None


class NewPassword(SQLModel):
    token: str
    new_password: str = Field(min_length=8, max_length=40)
