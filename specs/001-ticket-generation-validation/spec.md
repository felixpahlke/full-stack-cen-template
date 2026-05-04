# Feature Specification: CSV-Based Ticket Generation and Validation

**Feature Branch**: `001-ticket-generation-validation`  
**Created**: 2026-05-04  
**Status**: Draft  
**Input**: User description: "CSV-based ticket generation and QR code validation system for event entry management"

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Bulk Ticket Generation from CSV (Priority: P1)

An event administrator uploads a CSV file containing guest registration data (first name, last name, email, role, host email, guest age). The system processes each row, generates a unique ticket with a QR code for each guest, and stores the ticket information in the database.

**Why this priority**: This is the foundation of the ticketing system. Without the ability to generate tickets from registration data, no other functionality can work. This represents the core value proposition.

**Independent Test**: Can be fully tested by uploading a CSV file with sample guest data and verifying that tickets are created in the database with unique IDs and QR codes. Delivers immediate value by enabling ticket creation.

**Acceptance Scenarios**:

1. **Given** a valid CSV file with guest data, **When** the administrator uploads the file, **Then** the system creates one ticket per row with a unique ticket ID
2. **Given** a CSV file with 100 guest entries, **When** the file is processed, **Then** exactly 100 tickets are generated with unique QR codes
3. **Given** a CSV file with duplicate email addresses, **When** the file is processed, **Then** each entry still receives a unique ticket (multiple tickets per email allowed)
4. **Given** a CSV file with missing required fields, **When** the file is processed, **Then** the system reports validation errors for incomplete rows without creating tickets for those rows

---

### User Story 2 - Real-Time Ticket Validation via QR Scan (Priority: P2)

A ticket scanner at the event entrance uses an iPad/iPhone to scan a guest's QR code. The system immediately checks if the ticket is valid and has not been previously scanned. If valid, the system marks the ticket as scanned and grants entry. If already scanned or invalid, the system displays an error message.

**Why this priority**: This is the second most critical feature as it enables actual event entry control. Without validation, tickets have no security value. This must work in real-time to prevent duplicate entries.

**Independent Test**: Can be tested by generating test tickets, scanning their QR codes with a mobile device, and verifying that the first scan succeeds while subsequent scans are rejected. Delivers value by preventing unauthorized or duplicate entry.

**Acceptance Scenarios**:

1. **Given** a valid unscanned ticket QR code, **When** the scanner scans it, **Then** the system marks it as scanned and displays "Entry Granted"
2. **Given** a previously scanned ticket QR code, **When** the scanner attempts to scan it again, **Then** the system displays "Already Scanned - Entry Denied"
3. **Given** an invalid or non-existent ticket QR code, **When** the scanner scans it, **Then** the system displays "Invalid Ticket - Entry Denied"
4. **Given** the scanner device has no network connectivity, **When** attempting to scan a ticket, **Then** the system displays "Network Error - Cannot Validate"
5. **Given** multiple scanners operating simultaneously, **When** the same ticket is scanned on two devices within 1 second, **Then** only one scan succeeds and the other is rejected as duplicate

---

### User Story 3 - Ticket Status Monitoring Dashboard (Priority: P3)

An event administrator views a dashboard showing real-time statistics: total tickets generated, tickets scanned, tickets remaining, and recent scan activity. The dashboard updates automatically as tickets are scanned.

**Why this priority**: This provides operational visibility but is not critical for core ticket generation and validation. It enhances management capabilities but the event can run without it.

**Independent Test**: Can be tested by generating tickets, scanning some of them, and verifying that the dashboard displays accurate counts and updates in real-time. Delivers value by enabling capacity monitoring and operational insights.

**Acceptance Scenarios**:

1. **Given** 100 tickets generated and 30 scanned, **When** the administrator views the dashboard, **Then** it displays "Total: 100, Scanned: 30, Remaining: 70"
2. **Given** a ticket is scanned at the entrance, **When** the dashboard is open, **Then** the statistics update within 2 seconds without page refresh
3. **Given** the administrator views the dashboard, **When** requesting recent scan activity, **Then** the system displays the last 50 scans with timestamp, guest name, and scanner device

---

### Edge Cases

- What happens when the CSV file contains non-ASCII characters (German umlauts: ä, ö, ü, ß)?
- How does the system handle CSV files with inconsistent column counts (missing semicolons)?
- What happens when two scanners scan the same ticket at exactly the same moment (race condition)?
- How does the system handle QR codes that are damaged or partially unreadable?
- What happens when the CSV file is extremely large (10,000+ rows)?
- How does the system handle email addresses in different formats (uppercase, with spaces)?
- What happens when a ticket is scanned but the database update fails due to network issues?
- How does the system handle CSV files with different encodings (UTF-8, ISO-8859-1, UTF-8 with BOM)?
- What happens when the CSV file has trailing spaces in field values (e.g., "Max " instead of "Max")?
- How does the system handle the "Age Guest" field with values like "Adult", "Child", or empty?

## Requirements _(mandatory)_

### Functional Requirements

#### Ticket Generation

- **FR-001**: System MUST parse CSV files with semicolon-separated values containing: Vorname (first name), Nachname (last name), E-Mail, Rolle (role), E-mail Host Gast (host email), Age Guest
- **FR-002**: System MUST generate a globally unique ticket ID (UUID format) for each valid CSV row
- **FR-003**: System MUST generate a QR code encoding the unique ticket ID for each ticket
- **FR-004**: System MUST store ticket data in the database with fields: ticket_id, first_name, last_name, guest_email, role, host_email, guest_age, qr_code_data, is_scanned, scanned_at, email_sent, email_sent_at, email_delivery_status, created_at
- **FR-005**: System MUST enforce database uniqueness constraint on ticket_id to prevent duplicates
- **FR-006**: System MUST validate CSV rows before ticket creation, checking for required fields (first name, last name, email)
- **FR-007**: System MUST report validation errors for invalid CSV rows without halting processing of valid rows
- **FR-008**: System MUST support CSV files with UTF-8 encoding to handle German characters (ä, ö, ü, ß)
- **FR-009**: System MUST process CSV uploads atomically per row (individual row failures don't affect other rows)
- **FR-010**: System MUST normalize email addresses (lowercase, trim whitespace) before storage

#### Email Distribution

- **FR-011**: System MUST generate PDF tickets with embedded QR code, guest name, event details, and unique ticket ID
- **FR-012**: System MUST send ticket PDFs as email attachments to guest email addresses using SendGrid API
- **FR-013**: System MUST use a designated IBM email address as the sender (configured via SENDER_MAIL environment variable)
- **FR-014**: System MUST include event details, QR code scanning instructions, and support contact in email body
- **FR-015**: System MUST queue email sending operations after successful ticket generation
- **FR-016**: System MUST track email delivery status (pending/sent/failed) for each ticket
- **FR-017**: System MUST retry failed email sends up to 3 times with exponential backoff (1min, 5min, 15min)
- **FR-018**: System MUST mark tickets with permanent delivery failures (invalid email, bounced) for administrator review
- **FR-019**: System MUST log all email send attempts with: timestamp, ticket_id, recipient_email, delivery_status, error_message
- **FR-020**: System MUST handle SendGrid API rate limits gracefully with appropriate queuing

#### Ticket Validation

- **FR-021**: System MUST provide a QR code scanning interface optimized for iPad/iPhone with camera access
- **FR-022**: System MUST query the database in real-time when a QR code is scanned to check ticket validity and scan status
- **FR-023**: System MUST update ticket scan status (is_scanned=true, scanned_at=timestamp) immediately upon successful validation
- **FR-024**: System MUST prevent duplicate scans by checking is_scanned flag before granting entry
- **FR-025**: System MUST display clear validation results: "Entry Granted" (green), "Already Scanned" (red), "Invalid Ticket" (red), "Network Error" (yellow)
- **FR-026**: System MUST log all scan attempts with: timestamp, ticket_id, scanner_device_id, scan_result, user_id
- **FR-027**: System MUST handle concurrent scan attempts through database-level locking or atomic operations
- **FR-028**: System MUST require network connectivity for scanning devices during validation operations

#### Dashboard and Monitoring

- **FR-023**: System MUST provide a dashboard displaying: total tickets, scanned tickets, remaining tickets, recent scan activity
- **FR-024**: System MUST update dashboard statistics in real-time without requiring page refresh

#### Future: Email Distribution (Placeholder)

- **FR-025**: System SHOULD provide a placeholder/stub function for future email distribution functionality
- **FR-026**: Email distribution interface SHOULD be designed but not fully implemented in this phase

### Key Entities

- **Ticket**: Represents a single event entry permission. Key attributes: unique ticket ID (UUID), guest personal information (Vorname/first name, Nachname/last name, E-Mail, Age Guest), host information (E-mail Host Gast), role designation (Rolle), QR code data, scan status (boolean), scan timestamp, creation timestamp. Relationships: Links to the IBMer host who registered the guest, links to scan audit logs.

- **Guest Registration Data**: Represents the input data from Airtable CSV export. Key attributes: Vorname (first name), Nachname (last name), E-Mail, Rolle (role), Age Guest (optional text), E-mail Host Gast (host email). This is the source data that gets transformed into tickets. Note: Column order matches Airtable export format.

- **Ticket PDF**: Represents the generated PDF document containing the ticket. Key attributes: ticket ID reference, PDF file data/path, QR code image, guest name, event details, generation timestamp. Relationships: Links to the ticket. Can be downloaded by administrators.

- **Scan Event**: Represents a ticket validation attempt. Key attributes: timestamp, ticket ID reference, scanner device identifier, scan result (granted/denied/error), user ID of scanner operator. Relationships: Links to the ticket being scanned, links to audit trail.

- **Scanner Device**: Represents an iPad/iPhone used for validation. Key attributes: device identifier, device name, last active timestamp, assigned user. Relationships: Links to scan events performed by this device.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: Administrators can upload a CSV file with 500 guest entries and generate all tickets within 30 seconds
- **SC-002**: System correctly processes CSV files exported from Airtable with UTF-8 BOM encoding without data corruption
- **SC-003**: System correctly handles German special characters (ä, ö, ü, ß) in guest names and maintains them in tickets
- **SC-004**: System successfully trims whitespace from CSV fields (e.g., "Max " becomes "Max") in 100% of cases
- **SC-005**: Ticket validation (QR scan to entry decision) completes within 2 seconds under normal network conditions
- **SC-006**: System prevents 100% of duplicate ticket scans when the same QR code is scanned multiple times
- **SC-007**: System successfully handles concurrent scanning from 5 devices without validation errors or race conditions
- **SC-008**: Dashboard statistics update within 2 seconds of a ticket being scanned
- **SC-009**: 95% of QR code scans succeed on first attempt with standard mobile device cameras in typical event lighting
- **SC-010**: System maintains audit trail with 100% accuracy for all scan attempts (no missing or incorrect log entries)
- **SC-011**: PDF tickets are generated with clear, scannable QR codes that remain readable when downloaded
- **SC-012**: Administrators can view and download any generated ticket within 3 seconds

## Assumptions

- CSV files will be exported from Airtable and manually uploaded by administrators
- CSV files will use semicolon (;) as delimiter and UTF-8 encoding with BOM
- CSV column order is fixed: Vorname, Nachname, E-Mail, Rolle, Age Guest, E-mail Host Gast
- Guest email addresses in CSV are generally valid (validation errors handled gracefully)
- Scanner devices (iPads/iPhones) will have reliable WiFi or cellular connectivity during event operations
- QR codes will be displayed on mobile devices with sufficient quality for scanning
- The event venue has adequate network infrastructure to support real-time validation
- Multiple tickets per email address are allowed (one IBMer can register multiple guests)
- Ticket IDs do not need to be human-readable (UUIDs are acceptable)
- PDF tickets will be generated server-side (not client-side)
- Administrators will manually distribute tickets to guests (email automation is future feature)
- Walk-in registration (creating tickets without CSV import) is a future feature
- Role-based access control (scanner vs. admin roles) will be implemented but is not part of this initial spec
- Email distribution functionality will be designed as a placeholder for future implementation
