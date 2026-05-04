"""CSV parser utility for Airtable ticket data.

Handles UTF-8 BOM encoding, semicolon delimiters, and field validation.
"""

import csv
from io import StringIO
from typing import Any


class CSVParseError(Exception):
    """Exception raised for CSV parsing errors."""

    def __init__(self, row_number: int, message: str) -> None:
        self.row_number = row_number
        self.message = message
        super().__init__(f"Row {row_number}: {message}")


def parse_airtable_csv(
    content: bytes,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """Parse Airtable CSV export with semicolon delimiter and UTF-8 BOM.

    Expected columns (in order):
    - Vorname (first_name)
    - Nachname (last_name)
    - E-Mail (guest_email)
    - Rolle (role)
    - Age Guest (guest_age)
    - E-mail Host Gast (host_email)

    Args:
        content: Raw CSV file content as bytes

    Returns:
        Tuple of (valid_rows, errors) where:
        - valid_rows: List of dictionaries with normalized field names
        - errors: List of error dictionaries with 'row' and 'error' keys

    Raises:
        CSVParseError: If CSV format is invalid (e.g., encoding, missing headers)
    """
    # Decode with UTF-8 BOM handling
    try:
        text = content.decode("utf-8-sig")
    except UnicodeDecodeError as e:
        raise CSVParseError(0, f"Invalid UTF-8 encoding: {e}") from e

    # Parse CSV with semicolon delimiter
    reader = csv.DictReader(StringIO(text), delimiter=";")

    # Validate headers
    expected_headers = {
        "Vorname",
        "Nachname",
        "E-Mail",
        "Rolle",
        "Age Guest",
        "E-mail Host Gast",
    }
    if reader.fieldnames is None:
        raise CSVParseError(0, "CSV file is empty or has no headers")

    actual_headers = set(reader.fieldnames)
    missing_headers = expected_headers - actual_headers
    if missing_headers:
        raise CSVParseError(
            0, f"Missing required columns: {', '.join(sorted(missing_headers))}"
        )

    # Parse rows
    results = []
    errors = []

    for row_num, row in enumerate(reader, start=2):  # Start at 2 (header is row 1)
        try:
            parsed_row = _parse_row(row, row_num)
            results.append(parsed_row)
        except CSVParseError as e:
            errors.append({"row": e.row_number, "error": e.message})

    # Return both valid rows and errors
    # This allows partial success - valid rows are processed, invalid ones are reported
    return results, errors


def _parse_row(row: dict[str, str], row_num: int) -> dict[str, Any]:
    """Parse and validate a single CSV row.

    Args:
        row: Raw CSV row as dictionary
        row_num: Row number for error reporting

    Returns:
        Normalized dictionary with validated fields

    Raises:
        CSVParseError: If required fields are missing or invalid
    """
    # Trim whitespace from all fields
    trimmed = {k: v.strip() if v else "" for k, v in row.items()}

    # Validate required fields
    first_name = trimmed.get("Vorname", "")
    last_name = trimmed.get("Nachname", "")
    guest_email = trimmed.get("E-Mail", "")
    host_email = trimmed.get("E-mail Host Gast", "")

    if not first_name:
        raise CSVParseError(row_num, "Missing required field: Vorname (first name)")
    if not last_name:
        raise CSVParseError(row_num, "Missing required field: Nachname (last name)")
    if not guest_email:
        raise CSVParseError(row_num, "Missing required field: E-Mail (guest email)")
    if not host_email:
        raise CSVParseError(
            row_num, "Missing required field: E-mail Host Gast (host email)"
        )

    # Validate email format (basic check)
    if "@" not in guest_email or "." not in guest_email.split("@")[1]:
        raise CSVParseError(row_num, f"Invalid email format: {guest_email}")
    if "@" not in host_email or "." not in host_email.split("@")[1]:
        raise CSVParseError(row_num, f"Invalid host email format: {host_email}")

    # Normalize emails (lowercase, trim)
    guest_email_normalized = guest_email.lower().strip()
    host_email_normalized = host_email.lower().strip()

    # Optional fields
    role = trimmed.get("Rolle") or None
    guest_age = trimmed.get("Age Guest") or None

    return {
        "first_name": first_name,
        "last_name": last_name,
        "guest_email": guest_email_normalized,
        "role": role,
        "host_email": host_email_normalized,
        "guest_age": guest_age,
    }


# Made with Bob
