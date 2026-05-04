import base64
import uuid
from datetime import datetime
from typing import Any

from sqlmodel import Session, select

from app.core.security import get_password_hash, verify_password
from app.models import ItemCreate, TicketCreate, TicketUpdate, UserCreate, UserUpdate
from app.tables import (
    EmailQueue,
    EmailStatus,
    Item,
    ScanEvent,
    ScanResult,
    Ticket,
    User,
)
from app.utils.qr_generator import generate_qr_code


def create_user(*, session: Session, user_create: UserCreate) -> User:
    db_obj = User.model_validate(
        user_create, update={"hashed_password": get_password_hash(user_create.password)}
    )
    session.add(db_obj)
    session.commit()
    session.refresh(db_obj)
    return db_obj


def update_user(*, session: Session, db_user: User, user_in: UserUpdate) -> Any:
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
    return db_user


def get_user_by_email(*, session: Session, email: str) -> User | None:
    statement = select(User).where(User.email == email)
    session_user = session.exec(statement).first()
    return session_user


def authenticate(*, session: Session, email: str, password: str) -> User | None:
    db_user = get_user_by_email(session=session, email=email)
    if not db_user:
        return None
    if not verify_password(password, db_user.hashed_password):
        return None
    return db_user


def create_item(*, session: Session, item_in: ItemCreate, owner_id: uuid.UUID) -> Item:
    db_item = Item.model_validate(item_in, update={"owner_id": owner_id})
    session.add(db_item)
    session.commit()
    session.refresh(db_item)
    return db_item


# Ticket CRUD operations


def create_ticket(*, session: Session, ticket_in: TicketCreate) -> Ticket:
    """Create a new ticket with QR code data."""
    # Generate UUID for ticket
    ticket_id = uuid.uuid4()

    # Generate QR code as PNG bytes
    qr_code_bytes = generate_qr_code(ticket_id)

    # Convert to base64 data URL for embedding in HTML/JSON
    qr_code_base64 = base64.b64encode(qr_code_bytes).decode("utf-8")
    qr_code_data_url = f"data:image/png;base64,{qr_code_base64}"

    # Create ticket with QR code data
    db_ticket = Ticket.model_validate(
        ticket_in, update={"id": ticket_id, "qr_code_data": qr_code_data_url}
    )
    session.add(db_ticket)
    session.commit()
    session.refresh(db_ticket)
    return db_ticket


def create_tickets_bulk(
    *, session: Session, tickets_in: list[TicketCreate]
) -> list[Ticket]:
    """Create multiple tickets in a single transaction (atomic operation)."""
    db_tickets = []

    for ticket_in in tickets_in:
        ticket_id = uuid.uuid4()

        # Generate QR code as PNG bytes
        qr_code_bytes = generate_qr_code(ticket_id)

        # Convert to base64 data URL for embedding in HTML/JSON
        qr_code_base64 = base64.b64encode(qr_code_bytes).decode("utf-8")
        qr_code_data_url = f"data:image/png;base64,{qr_code_base64}"

        db_ticket = Ticket.model_validate(
            ticket_in, update={"id": ticket_id, "qr_code_data": qr_code_data_url}
        )
        db_tickets.append(db_ticket)
        session.add(db_ticket)

    session.commit()

    # Refresh all tickets
    for db_ticket in db_tickets:
        session.refresh(db_ticket)

    return db_tickets


def get_ticket(*, session: Session, ticket_id: uuid.UUID) -> Ticket | None:
    """Get a ticket by ID."""
    return session.get(Ticket, ticket_id)


def get_ticket_by_qr_code(*, session: Session, qr_code_data: str) -> Ticket | None:
    """Get a ticket by QR code data."""
    statement = select(Ticket).where(Ticket.qr_code_data == qr_code_data)
    return session.exec(statement).first()


def get_tickets(*, session: Session, skip: int = 0, limit: int = 100) -> list[Ticket]:
    """Get all tickets with pagination."""
    statement = select(Ticket).offset(skip).limit(limit)
    return list(session.exec(statement).all())


def get_tickets_by_host_email(
    *, session: Session, host_email: str, skip: int = 0, limit: int = 100
) -> list[Ticket]:
    """Get all tickets for a specific host (IBMer)."""
    statement = (
        select(Ticket).where(Ticket.host_email == host_email).offset(skip).limit(limit)
    )
    return list(session.exec(statement).all())


def update_ticket(
    *, session: Session, ticket_id: uuid.UUID, ticket_in: TicketUpdate
) -> Ticket | None:
    """Update a ticket."""
    db_ticket = session.get(Ticket, ticket_id)
    if not db_ticket:
        return None

    ticket_data = ticket_in.model_dump(exclude_unset=True)
    db_ticket.sqlmodel_update(ticket_data)
    session.add(db_ticket)
    session.commit()
    session.refresh(db_ticket)
    return db_ticket


def delete_ticket(*, session: Session, ticket_id: uuid.UUID) -> bool:
    """Delete a ticket by ID.

    Deletes associated ScanEvents and EmailQueue entries first (cascade delete).
    Returns True if deleted, False if ticket not found.
    """
    db_ticket = session.get(Ticket, ticket_id)
    if not db_ticket:
        return False

    # Delete associated scan events first
    scan_events_statement = select(ScanEvent).where(ScanEvent.ticket_id == ticket_id)
    scan_events = session.exec(scan_events_statement).all()
    for scan_event in scan_events:
        session.delete(scan_event)

    # Delete associated email queue entries
    email_queue_statement = select(EmailQueue).where(EmailQueue.ticket_id == ticket_id)
    email_queue_entries = session.exec(email_queue_statement).all()
    for email_entry in email_queue_entries:
        session.delete(email_entry)

    # Now delete the ticket
    session.delete(db_ticket)
    session.commit()
    return True


def mark_ticket_scanned(
    *,
    session: Session,
    ticket_id: uuid.UUID,
    scanner_device_id: str,
    scanner_user_id: str,
) -> tuple[Ticket, ScanEvent] | None:
    """Mark a ticket as scanned and create scan event audit log.

    Returns tuple of (ticket, scan_event) if successful, None if ticket not found.
    """
    db_ticket = session.get(Ticket, ticket_id)
    if not db_ticket:
        return None

    # Update ticket scan status
    db_ticket.is_scanned = True
    db_ticket.scanned_at = datetime.utcnow()
    db_ticket.scanner_device_id = scanner_device_id
    db_ticket.scanner_user_id = scanner_user_id

    # Create scan event audit log
    scan_event = ScanEvent(
        ticket_id=ticket_id,
        scanner_device_id=scanner_device_id,
        scanner_user_id=scanner_user_id,
        scan_result=ScanResult.granted,
    )

    session.add(db_ticket)
    session.add(scan_event)
    session.commit()
    session.refresh(db_ticket)
    session.refresh(scan_event)

    return db_ticket, scan_event


def create_scan_event(
    *,
    session: Session,
    ticket_id: uuid.UUID,
    scanner_device_id: str,
    scanner_user_id: str,
    scan_result: ScanResult,
) -> ScanEvent:
    """Create a scan event audit log entry."""
    scan_event = ScanEvent(
        ticket_id=ticket_id,
        scanner_device_id=scanner_device_id,
        scanner_user_id=scanner_user_id,
        scan_result=scan_result,
    )
    session.add(scan_event)
    session.commit()
    session.refresh(scan_event)
    return scan_event


def get_scan_events_by_ticket(
    *, session: Session, ticket_id: uuid.UUID
) -> list[ScanEvent]:
    """Get all scan events for a specific ticket."""
    statement = select(ScanEvent).where(ScanEvent.ticket_id == ticket_id)
    return list(session.exec(statement).all())


def queue_email(
    *,
    session: Session,
    ticket_id: uuid.UUID,
    recipient_email: str,
    subject: str,
    html_body: str,
    pdf_attachment_path: str,
) -> EmailQueue:
    """Queue an email for sending."""
    email_queue = EmailQueue(
        ticket_id=ticket_id,
        recipient_email=recipient_email,
        subject=subject,
        html_body=html_body,
        pdf_attachment_path=pdf_attachment_path,
    )
    session.add(email_queue)
    session.commit()
    session.refresh(email_queue)
    return email_queue


def get_pending_emails(*, session: Session, limit: int = 10) -> list[EmailQueue]:
    """Get pending emails from the queue."""
    statement = select(EmailQueue).where(EmailQueue.status == "pending").limit(limit)
    return list(session.exec(statement).all())


def update_email_status(
    *,
    session: Session,
    email_id: uuid.UUID,
    status: EmailStatus,
    error_message: str | None = None,
) -> EmailQueue | None:
    """Update email queue status."""
    db_email = session.get(EmailQueue, email_id)
    if not db_email:
        return None

    db_email.status = status
    if error_message:
        db_email.last_error = error_message
    if status == EmailStatus.sent:
        db_email.processed_at = datetime.utcnow()

    session.add(db_email)
    session.commit()
    session.refresh(db_email)
    return db_email
