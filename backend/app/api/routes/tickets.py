"""API routes for ticket management."""

import logging
import uuid
from typing import Any

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlmodel import Session, func, select

from app import crud
from app.api.deps import get_db
from app.models import (
    ScanEventPublic,
    ScanEventsPublic,
    TicketCreate,
    TicketPublic,
    TicketsPublic,
    TicketUpdate,
)
from app.tables import ScanResult, Ticket
from app.utils.csv_parser import CSVParseError, parse_airtable_csv
from app.utils.pdf_generator import generate_ticket_pdf

router = APIRouter()


@router.post("/upload-csv", response_model=dict[str, Any])
def upload_csv_and_generate_tickets(
    *,
    session: Session = Depends(get_db),
    file: UploadFile = File(...),
) -> dict[str, Any]:
    """Upload CSV file and generate tickets for all guests.

    Expected CSV format (Airtable export):
    - Semicolon delimiter
    - UTF-8 with BOM encoding
    - Columns: Vorname, Nachname, E-Mail, Rolle, Age Guest, E-mail Host Gast

    Returns:
        Dictionary with success count, error count, and details
    """
    # Validate file type
    if not file.filename or not file.filename.endswith(".csv"):
        raise HTTPException(status_code=400, detail="File must be a CSV file")

    # Read file content
    try:
        content = file.file.read()
    except Exception as e:
        raise HTTPException(
            status_code=400, detail=f"Failed to read file: {str(e)}"
        ) from e

    # Parse CSV
    try:
        parsed_rows, parse_errors = parse_airtable_csv(content)
    except CSVParseError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e

    if not parsed_rows and parse_errors:
        # All rows failed validation
        raise HTTPException(
            status_code=400,
            detail=f"CSV file contains no valid rows. {len(parse_errors)} errors found.",
        )

    # Create tickets from parsed data
    tickets_to_create = []
    for row in parsed_rows:
        ticket_create = TicketCreate(
            first_name=row["first_name"],
            last_name=row["last_name"],
            guest_email=row["guest_email"],
            role=row.get("role"),
            host_email=row["host_email"],
            guest_age=row.get("guest_age"),
        )
        tickets_to_create.append(ticket_create)

    # Bulk create tickets (atomic operation per valid row)
    try:
        created_tickets = crud.create_tickets_bulk(
            session=session, tickets_in=tickets_to_create
        )
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to create tickets: {str(e)}"
        ) from e

    # Queue emails for all created tickets
    logger = logging.getLogger(__name__)
    email_queue_errors = []

    for ticket in created_tickets:
        try:
            crud.queue_email(
                session=session,
                ticket_id=ticket.id,
                recipient_email=ticket.guest_email,
                subject="Your Event Ticket",
                html_body=f"<p>Dear {ticket.first_name} {ticket.last_name},</p><p>Your ticket is attached.</p>",
                pdf_attachment_path=f"/tmp/ticket_{ticket.id}.pdf",  # TODO: Generate actual PDF in Phase 6
            )
        except Exception as e:
            # Log error but don't fail the entire operation
            error_msg = f"Failed to queue email for ticket {ticket.id}: {str(e)}"
            logger.error(error_msg)
            email_queue_errors.append({"ticket_id": str(ticket.id), "error": str(e)})

    return {
        "success": True,
        "tickets_created": len(created_tickets),
        "tickets_failed": len(parse_errors),
        "total_rows": len(parsed_rows) + len(parse_errors),
        "errors": parse_errors,
        "ticket_ids": [str(ticket.id) for ticket in created_tickets],
        "email_queue_errors": email_queue_errors if email_queue_errors else None,
    }


@router.get("/", response_model=TicketsPublic)
def read_tickets(
    session: Session = Depends(get_db), skip: int = 0, limit: int = 100
) -> TicketsPublic:
    """Get all tickets with pagination."""
    tickets = crud.get_tickets(session=session, skip=skip, limit=limit)

    # Get total count
    count_statement = select(func.count()).select_from(Ticket)
    count = session.exec(count_statement).one()

    # Convert to public models
    tickets_public = [TicketPublic.model_validate(ticket) for ticket in tickets]

    return TicketsPublic(data=tickets_public, count=count)


@router.get("/by-host/{host_email}", response_model=TicketsPublic)
def read_tickets_by_host(
    host_email: str,
    session: Session = Depends(get_db),
    skip: int = 0,
    limit: int = 100,
) -> TicketsPublic:
    """Get all tickets for a specific host (IBMer)."""
    tickets = crud.get_tickets_by_host_email(
        session=session, host_email=host_email, skip=skip, limit=limit
    )

    # Get total count for this host
    count_statement = (
        select(func.count()).select_from(Ticket).where(Ticket.host_email == host_email)
    )
    count = session.exec(count_statement).one()

    # Convert to public models
    tickets_public = [TicketPublic.model_validate(ticket) for ticket in tickets]

    return TicketsPublic(data=tickets_public, count=count)


@router.get("/dashboard", response_model=dict[str, Any])
def get_dashboard_stats(session: Session = Depends(get_db)) -> dict[str, Any]:
    """Get real-time dashboard statistics for ticket monitoring.

    Returns:
        Dictionary with total tickets, scanned tickets, remaining tickets, and scan rate
    """
    from datetime import datetime, timedelta

    # Get total ticket count
    total_statement = select(func.count()).select_from(Ticket)
    total_tickets = session.exec(total_statement).one()

    # Get scanned ticket count
    scanned_statement = (
        select(func.count()).select_from(Ticket).where(Ticket.is_scanned == True)
    )
    scanned_tickets = session.exec(scanned_statement).one()

    # Calculate remaining tickets
    remaining_tickets = total_tickets - scanned_tickets

    # Calculate scan rate per minute (last 5 minutes)
    # Query tickets scanned in the last 5 minutes
    five_minutes_ago = datetime.utcnow() - timedelta(minutes=5)
    recent_tickets = session.exec(
        select(Ticket).where(Ticket.is_scanned == True).where(Ticket.scanned_at != None)
    ).all()

    # Filter in Python to avoid type issues
    recent_scans = sum(
        1 for t in recent_tickets if t.scanned_at and t.scanned_at >= five_minutes_ago
    )
    scan_rate_per_minute = round(recent_scans / 5.0, 2) if recent_scans > 0 else 0.0

    return {
        "total_tickets": total_tickets,
        "scanned_tickets": scanned_tickets,
        "remaining_tickets": remaining_tickets,
        "scan_rate_per_minute": scan_rate_per_minute,
    }


@router.get("/recent-scans", response_model=ScanEventsPublic)
def get_recent_scans(
    session: Session = Depends(get_db), limit: int = 50
) -> ScanEventsPublic:
    """Get recent scan events for monitoring dashboard.

    Returns the last N scan events with ticket details, ordered by timestamp descending.

    Args:
        limit: Maximum number of scan events to return (default: 50)

    Returns:
        ScanEventsPublic with recent scan events
    """
    from app.tables import ScanEvent

    # Get all scan events and sort in Python to avoid type issues
    all_events = session.exec(select(ScanEvent)).all()
    # Sort by timestamp descending and limit
    scan_events = sorted(all_events, key=lambda e: e.timestamp, reverse=True)[:limit]

    # Convert to public models
    scan_events_public = [
        ScanEventPublic.model_validate(event) for event in scan_events
    ]

    return ScanEventsPublic(data=scan_events_public, count=len(scan_events_public))


@router.get("/{ticket_id}", response_model=TicketPublic)
def read_ticket(ticket_id: uuid.UUID, session: Session = Depends(get_db)) -> Ticket:
    """Get a specific ticket by ID."""
    ticket = crud.get_ticket(session=session, ticket_id=ticket_id)
    if not ticket:
        raise HTTPException(status_code=404, detail="Ticket not found")
    return ticket


@router.get("/{ticket_id}/pdf")
def download_ticket_pdf(
    ticket_id: uuid.UUID, session: Session = Depends(get_db)
) -> Any:
    """Download ticket as PDF."""
    from fastapi.responses import Response

    ticket = crud.get_ticket(session=session, ticket_id=ticket_id)
    if not ticket:
        raise HTTPException(status_code=404, detail="Ticket not found")

    # Generate PDF
    pdf_bytes = generate_ticket_pdf(
        ticket_id=ticket.id,
        first_name=ticket.first_name,
        last_name=ticket.last_name,
        guest_email=ticket.guest_email,
        event_name="IBM Event",
        event_location="IBM Location",
    )

    # Return PDF as response
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f"attachment; filename=ticket_{ticket_id}.pdf"},
    )


@router.patch("/{ticket_id}", response_model=TicketPublic)
def update_ticket(
    ticket_id: uuid.UUID,
    ticket_in: TicketUpdate,
    session: Session = Depends(get_db),
) -> Ticket:
    """Update a ticket."""
    ticket = crud.update_ticket(
        session=session, ticket_id=ticket_id, ticket_in=ticket_in
    )
    if not ticket:
        raise HTTPException(status_code=404, detail="Ticket not found")
    return ticket


@router.delete("/{ticket_id}", status_code=204)
def delete_ticket(ticket_id: uuid.UUID, session: Session = Depends(get_db)) -> None:
    """Delete a ticket by ID."""
    success = crud.delete_ticket(session=session, ticket_id=ticket_id)
    if not success:
        raise HTTPException(status_code=404, detail="Ticket not found")


@router.post("/{ticket_id}/validate", response_model=dict[str, Any])
def validate_ticket(
    ticket_id: uuid.UUID,
    session: Session = Depends(get_db),
    scanner_device_id: str = "",
    scanner_user_id: str = "",
) -> dict[str, Any]:
    """Validate a ticket for entry (real-time duplicate prevention).

    Uses row-level locking (SELECT ... FOR UPDATE) to prevent race conditions
    when multiple scanners attempt to validate the same ticket simultaneously.

    Returns:
        Dictionary with validation result and ticket status
    """
    # Get ticket with row-level lock to prevent concurrent validation
    statement = select(Ticket).where(Ticket.id == ticket_id).with_for_update()
    ticket = session.exec(statement).first()

    if not ticket:
        # Create scan event for invalid ticket
        crud.create_scan_event(
            session=session,
            ticket_id=ticket_id,
            scanner_device_id=scanner_device_id,
            scanner_user_id=scanner_user_id,
            scan_result=ScanResult.invalid,
        )
        return {
            "valid": False,
            "result": "invalid",
            "message": "Ticket not found",
        }

    # Check if already scanned
    if ticket.is_scanned:
        # Create scan event for duplicate scan attempt
        crud.create_scan_event(
            session=session,
            ticket_id=ticket_id,
            scanner_device_id=scanner_device_id,
            scanner_user_id=scanner_user_id,
            scan_result=ScanResult.already_scanned,
        )
        return {
            "valid": False,
            "result": "already_scanned",
            "message": f"Ticket already scanned at {ticket.scanned_at}",
            "scanned_at": ticket.scanned_at,
            "scanned_by_device": ticket.scanner_device_id,
        }

    # Mark ticket as scanned
    result = crud.mark_ticket_scanned(
        session=session,
        ticket_id=ticket_id,
        scanner_device_id=scanner_device_id,
        scanner_user_id=scanner_user_id,
    )

    if not result:
        raise HTTPException(status_code=500, detail="Failed to mark ticket as scanned")

    updated_ticket, scan_event = result

    return {
        "valid": True,
        "result": "granted",
        "message": "Entry granted",
        "ticket": TicketPublic.model_validate(updated_ticket),
        "scan_event_id": str(scan_event.id),
    }


@router.get("/{ticket_id}/scan-events", response_model=ScanEventsPublic)
def read_ticket_scan_events(
    ticket_id: uuid.UUID, session: Session = Depends(get_db)
) -> ScanEventsPublic:
    """Get all scan events for a specific ticket (audit trail)."""
    # Verify ticket exists
    ticket = crud.get_ticket(session=session, ticket_id=ticket_id)
    if not ticket:
        raise HTTPException(status_code=404, detail="Ticket not found")

    # Get scan events
    scan_events = crud.get_scan_events_by_ticket(session=session, ticket_id=ticket_id)

    # Convert to public models
    scan_events_public = [
        ScanEventPublic.model_validate(event) for event in scan_events
    ]

    return ScanEventsPublic(data=scan_events_public, count=len(scan_events_public))


# Made with Bob
