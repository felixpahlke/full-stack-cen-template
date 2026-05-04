import uuid
from datetime import datetime
from enum import Enum

from pydantic import EmailStr
from sqlmodel import Field, Relationship, SQLModel


# Enums for ticket system
class ScanResult(str, Enum):
    granted = "granted"
    already_scanned = "already_scanned"
    invalid = "invalid"
    network_error = "network_error"


class EmailStatus(str, Enum):
    pending = "pending"
    processing = "processing"
    sent = "sent"
    failed = "failed"
    bounced = "bounced"


# Database model, database table inferred from class name
class User(SQLModel, table=True):
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    email: EmailStr = Field(unique=True, index=True, max_length=255)
    is_active: bool = True
    is_superuser: bool = False
    full_name: str | None = Field(default=None, max_length=255)
    hashed_password: str
    items: list["Item"] = Relationship(back_populates="owner", cascade_delete=True)


class Item(SQLModel, table=True):
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    title: str = Field(min_length=1, max_length=255)
    description: str | None = Field(default=None, max_length=255)
    owner_id: uuid.UUID = Field(
        foreign_key="user.id", nullable=False, ondelete="CASCADE"
    )
    owner: User | None = Relationship(back_populates="items")


# Ticket table - represents event entry permissions
class Ticket(SQLModel, table=True):
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    first_name: str = Field(max_length=255)
    last_name: str = Field(max_length=255)
    guest_email: str = Field(max_length=255, index=True)
    role: str | None = Field(default=None, max_length=255)
    host_email: str = Field(max_length=255, index=True)
    guest_age: str | None = Field(default=None, max_length=100)
    qr_code_data: str = Field(
        max_length=20000
    )  # Base64-encoded PNG QR codes can be up to ~15000 chars
    is_scanned: bool = Field(default=False, index=True)
    scanned_at: datetime | None = Field(default=None)
    scanner_device_id: str | None = Field(default=None, max_length=255)
    scanner_user_id: str | None = Field(default=None, max_length=255)
    email_sent: bool = Field(default=False)
    email_sent_at: datetime | None = Field(default=None)
    email_delivery_status: EmailStatus = Field(default=EmailStatus.pending, index=True)
    email_retry_count: int = Field(default=0)
    created_at: datetime = Field(default_factory=datetime.utcnow, index=True)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


# ScanEvent table - immutable audit log of validation attempts
class ScanEvent(SQLModel, table=True):
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    ticket_id: uuid.UUID = Field(foreign_key="ticket.id", index=True)
    timestamp: datetime = Field(default_factory=datetime.utcnow, index=True)
    scanner_device_id: str = Field(max_length=255, index=True)
    scanner_user_id: str = Field(max_length=255)
    scan_result: ScanResult
    error_message: str | None = Field(default=None, max_length=1000)
    network_latency_ms: int | None = Field(default=None)


# EmailQueue table - background job queue for email delivery
class EmailQueue(SQLModel, table=True):
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    ticket_id: uuid.UUID = Field(foreign_key="ticket.id", index=True)
    recipient_email: str = Field(max_length=255)
    subject: str = Field(max_length=500)
    html_body: str
    pdf_attachment_path: str = Field(max_length=1000)
    status: EmailStatus = Field(default=EmailStatus.pending, index=True)
    retry_count: int = Field(default=0)
    next_retry_at: datetime | None = Field(default=None, index=True)
    last_error: str | None = Field(default=None)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    processed_at: datetime | None = Field(default=None)
