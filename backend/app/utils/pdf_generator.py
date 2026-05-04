"""PDF ticket generator utility.

Creates printable PDF tickets with QR codes, guest information, and event details.
"""

import io
import uuid
from datetime import datetime

from PIL import Image
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.pdfgen import canvas

from .qr_generator import generate_qr_code_pil


def generate_ticket_pdf(
    ticket_id: uuid.UUID,
    first_name: str,
    last_name: str,
    guest_email: str,
    event_name: str = "IBM Event",
    event_date: str | None = None,
    event_location: str = "IBM Location",
) -> bytes:
    """Generate a PDF ticket with QR code and guest information.

    Args:
        ticket_id: UUID of the ticket
        first_name: Guest's first name
        last_name: Guest's last name
        guest_email: Guest's email address
        event_name: Name of the event (default: "IBM Event")
        event_date: Date of the event (default: None)
        event_location: Location of the event (default: "IBM Location")

    Returns:
        PDF file data as bytes
    """
    # Create PDF buffer
    buffer = io.BytesIO()

    # Create canvas (A4 size)
    c = canvas.Canvas(buffer, pagesize=A4)
    width, height = A4

    # Set up fonts and colors
    c.setFont("Helvetica-Bold", 24)

    # Title
    c.drawCentredString(width / 2, height - 3 * cm, event_name)

    # Event details
    c.setFont("Helvetica", 12)
    y_position = height - 4.5 * cm

    if event_date:
        c.drawCentredString(width / 2, y_position, f"Date: {event_date}")
        y_position -= 0.7 * cm

    c.drawCentredString(width / 2, y_position, f"Location: {event_location}")
    y_position -= 1.5 * cm

    # Guest information
    c.setFont("Helvetica-Bold", 16)
    c.drawCentredString(width / 2, y_position, "Guest Information")
    y_position -= 1 * cm

    c.setFont("Helvetica", 14)
    c.drawCentredString(width / 2, y_position, f"{first_name} {last_name}")
    y_position -= 0.7 * cm

    c.setFont("Helvetica", 10)
    c.drawCentredString(width / 2, y_position, guest_email)
    y_position -= 2 * cm

    # QR Code
    qr_img = generate_qr_code_pil(ticket_id, size=400)

    # Save QR code to temporary buffer
    qr_buffer = io.BytesIO()
    qr_img.save(qr_buffer, format="PNG")
    qr_buffer.seek(0)

    # Draw QR code centered
    qr_size = 8 * cm
    qr_x = (width - qr_size) / 2
    qr_y = y_position - qr_size

    c.drawImage(
        qr_buffer,
        qr_x,
        qr_y,
        width=qr_size,
        height=qr_size,
        preserveAspectRatio=True,
    )

    # Ticket ID below QR code
    c.setFont("Helvetica", 8)
    c.drawCentredString(width / 2, qr_y - 0.7 * cm, f"Ticket ID: {ticket_id}")

    # Instructions at bottom
    c.setFont("Helvetica", 10)
    instructions_y = 3 * cm
    c.drawCentredString(
        width / 2,
        instructions_y,
        "Please present this QR code at the event entrance for validation.",
    )
    c.drawCentredString(
        width / 2,
        instructions_y - 0.5 * cm,
        "Each ticket can only be scanned once.",
    )

    # Footer with generation timestamp
    c.setFont("Helvetica", 8)
    c.drawCentredString(
        width / 2,
        1.5 * cm,
        f"Generated: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}",
    )

    # Finalize PDF
    c.showPage()
    c.save()

    # Get PDF bytes
    buffer.seek(0)
    return buffer.getvalue()


def generate_bulk_tickets_pdf(
    tickets: list[dict],
    event_name: str = "IBM Event",
    event_date: str | None = None,
    event_location: str = "IBM Location",
) -> bytes:
    """Generate a multi-page PDF with multiple tickets.

    Args:
        tickets: List of ticket dictionaries with keys:
            - ticket_id: UUID
            - first_name: str
            - last_name: str
            - guest_email: str
        event_name: Name of the event
        event_date: Date of the event
        event_location: Location of the event

    Returns:
        PDF file data as bytes with one ticket per page
    """
    # Create PDF buffer
    buffer = io.BytesIO()

    # Create canvas (A4 size)
    c = canvas.Canvas(buffer, pagesize=A4)
    width, height = A4

    for ticket in tickets:
        # Set up fonts and colors
        c.setFont("Helvetica-Bold", 24)

        # Title
        c.drawCentredString(width / 2, height - 3 * cm, event_name)

        # Event details
        c.setFont("Helvetica", 12)
        y_position = height - 4.5 * cm

        if event_date:
            c.drawCentredString(width / 2, y_position, f"Date: {event_date}")
            y_position -= 0.7 * cm

        c.drawCentredString(width / 2, y_position, f"Location: {event_location}")
        y_position -= 1.5 * cm

        # Guest information
        c.setFont("Helvetica-Bold", 16)
        c.drawCentredString(width / 2, y_position, "Guest Information")
        y_position -= 1 * cm

        c.setFont("Helvetica", 14)
        c.drawCentredString(
            width / 2,
            y_position,
            f"{ticket['first_name']} {ticket['last_name']}",
        )
        y_position -= 0.7 * cm

        c.setFont("Helvetica", 10)
        c.drawCentredString(width / 2, y_position, ticket["guest_email"])
        y_position -= 2 * cm

        # QR Code
        qr_img = generate_qr_code_pil(ticket["ticket_id"], size=400)

        # Save QR code to temporary buffer
        qr_buffer = io.BytesIO()
        qr_img.save(qr_buffer, format="PNG")
        qr_buffer.seek(0)

        # Draw QR code centered
        qr_size = 8 * cm
        qr_x = (width - qr_size) / 2
        qr_y = y_position - qr_size

        c.drawImage(
            qr_buffer,
            qr_x,
            qr_y,
            width=qr_size,
            height=qr_size,
            preserveAspectRatio=True,
        )

        # Ticket ID below QR code
        c.setFont("Helvetica", 8)
        c.drawCentredString(
            width / 2, qr_y - 0.7 * cm, f"Ticket ID: {ticket['ticket_id']}"
        )

        # Instructions at bottom
        c.setFont("Helvetica", 10)
        instructions_y = 3 * cm
        c.drawCentredString(
            width / 2,
            instructions_y,
            "Please present this QR code at the event entrance for validation.",
        )
        c.drawCentredString(
            width / 2,
            instructions_y - 0.5 * cm,
            "Each ticket can only be scanned once.",
        )

        # Footer with generation timestamp
        c.setFont("Helvetica", 8)
        c.drawCentredString(
            width / 2,
            1.5 * cm,
            f"Generated: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}",
        )

        # New page for next ticket
        c.showPage()

    # Finalize PDF
    c.save()

    # Get PDF bytes
    buffer.seek(0)
    return buffer.getvalue()


# Made with Bob
