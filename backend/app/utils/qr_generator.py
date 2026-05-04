"""QR code generator utility for ticket validation.

Generates QR codes encoding ticket UUIDs for scanning at event entry.
"""

import io
import uuid
from typing import Any

import qrcode
from PIL import Image


def generate_qr_code(ticket_id: uuid.UUID, size: int = 200) -> bytes:
    """Generate QR code image for a ticket ID.

    Args:
        ticket_id: UUID of the ticket to encode
        size: Size of the QR code image in pixels (default: 200x200)

    Returns:
        PNG image data as bytes

    Raises:
        ValueError: If size is invalid
    """
    if size < 100 or size > 1000:
        raise ValueError("QR code size must be between 100 and 1000 pixels")

    # Create QR code instance with medium error correction for smaller file size
    qr = qrcode.QRCode(
        version=1,  # Auto-adjust version based on data
        error_correction=qrcode.ERROR_CORRECT_M,  # Medium error correction (15%)
        box_size=8,  # Size of each box in pixels (reduced from 10)
        border=2,  # Border size in boxes (reduced from 4)
    )

    # Add ticket ID data
    qr.add_data(str(ticket_id))
    qr.make(fit=True)

    # Create image with PIL backend
    img: Any = qr.make_image(fill_color="black", back_color="white")

    # Convert to PIL Image if needed and resize
    if not isinstance(img, Image.Image):
        img = img.convert("RGB")

    img = img.resize((size, size), Image.Resampling.LANCZOS)

    # Convert to PNG bytes with optimization
    buffer = io.BytesIO()
    img.save(buffer, format="PNG", optimize=True)
    return buffer.getvalue()


def generate_qr_code_pil(ticket_id: uuid.UUID, size: int = 200) -> Image.Image:
    """Generate QR code as PIL Image for embedding in PDFs.

    Args:
        ticket_id: UUID of the ticket to encode
        size: Size of the QR code image in pixels (default: 200x200)

    Returns:
        PIL Image object

    Raises:
        ValueError: If size is invalid
    """
    if size < 100 or size > 1000:
        raise ValueError("QR code size must be between 100 and 1000 pixels")

    # Create QR code instance with medium error correction for smaller file size
    qr = qrcode.QRCode(
        version=1,  # Auto-adjust version based on data
        error_correction=qrcode.ERROR_CORRECT_M,  # Medium error correction (15%)
        box_size=8,  # Size of each box in pixels (reduced from 10)
        border=2,  # Border size in boxes (reduced from 4)
    )

    # Add ticket ID data
    qr.add_data(str(ticket_id))
    qr.make(fit=True)

    # Create image with PIL backend
    img: Any = qr.make_image(fill_color="black", back_color="white")

    # Convert to PIL Image if needed and resize
    if not isinstance(img, Image.Image):
        img = img.convert("RGB")

    img = img.resize((size, size), Image.Resampling.LANCZOS)

    return img


def validate_qr_data(qr_data: str) -> uuid.UUID | None:
    """Validate and parse QR code data.

    Args:
        qr_data: Raw QR code data string

    Returns:
        UUID if valid, None otherwise
    """
    try:
        return uuid.UUID(qr_data)
    except (ValueError, AttributeError):
        return None


# Made with Bob
