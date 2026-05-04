# Implementation Plan: CSV-Based Ticket Generation and Validation

**Feature Branch**: `001-ticket-generation-validation`  
**Created**: 2026-05-04  
**Status**: In Progress

## Technical Context

### Technology Stack

- **Backend Framework**: FastAPI with SQLModel ORM
- **Database**: PostgreSQL with Alembic migrations
- **Frontend Framework**: React 19 with TypeScript, Vite, TanStack Router/Query
- **UI Library**: IBM Carbon Design System
- **Package Manager**: UV (backend), npm (frontend)
- **Infrastructure**: Docker Compose (development), OpenShift (production)
- **Authentication**: OAuth2 Proxy with IBM AppID (production), local auth (development)

### Existing Infrastructure

- **Email Service**: SendGrid API integration already implemented at `backend/app/api/routes/mail.py`
- **Email Configuration**: `SENDGRID_API_KEY` and `SENDER_MAIL` environment variables
- **Base Models**: Item/User models exist as reference patterns
- **Database**: PostgreSQL with Alembic migration system
- **API Structure**: FastAPI with route organization in `backend/app/api/routes/`

### Key Dependencies

- **QR Code Generation**: `qrcode` Python library (needs to be added)
- **PDF Generation**: `reportlab` or `fpdf2` Python library (needs to be added)
- **CSV Processing**: Python built-in `csv` module
- **Email Sending**: SendGrid API (already integrated)
- **Camera Access**: Browser WebRTC API for QR scanning (frontend)
- **QR Scanning**: `html5-qrcode` or `@zxing/browser` npm package (needs to be added)

### Integration Points

- **CSV Upload**: File upload endpoint with multipart/form-data
- **Email Service**: Existing SendGrid integration at `/api/v1/mail/sendgrid/send`
- **Database**: PostgreSQL with connection pooling via SQLModel
- **Frontend-Backend**: REST API with auto-generated TypeScript client
- **Camera API**: Browser WebRTC for mobile QR scanning

### Technical Constraints

- **CSV Format**: Semicolon-delimited, UTF-8 with BOM encoding
- **CSV Columns**: Fixed order - Vorname, Nachname, E-Mail, Rolle, Age Guest, E-mail Host Gast
- **QR Code Content**: UUID only (no personal data)
- **PDF Size**: Must be email-attachment friendly (<5MB per ticket)
- **Concurrent Scanning**: Must handle 5+ simultaneous scanning devices
- **Network Dependency**: Scanner devices require active connectivity
- **Database Locking**: Row-level locking for scan operations to prevent race conditions

### Performance Requirements

- **CSV Processing**: 500 rows in <30 seconds
- **Ticket Validation**: <2 seconds from scan to decision
- **Dashboard Updates**: <2 seconds real-time refresh
- **QR Scan Success Rate**: 95% first-attempt success
- **Concurrent Users**: Support 5+ simultaneous scanners

### Security Considerations

- **Data Privacy**: QR codes contain only ticket UUID, not personal data
- **Database Encryption**: Sensitive fields encrypted at rest
- **API Authentication**: All endpoints require authentication
- **Audit Logging**: All scans and modifications logged with user/device ID
- **Role Separation**: Scanner role cannot modify registrations
- **Email Validation**: Normalize and validate email addresses

## Constitution Check

### Principle 1: Ticket Uniqueness and Validation Integrity ✅

- **Compliance**: UUID primary key with database uniqueness constraint
- **Implementation**: PostgreSQL UUID type with unique index
- **Validation**: QR codes encode only ticket UUID
- **Persistence**: Immediate database update on successful scan with transaction commit
- **Race Condition Prevention**: Row-level locking with `SELECT ... FOR UPDATE`

### Principle 2: Real-Time Validation and Duplicate Prevention ✅

- **Compliance**: All validation queries hit database immediately
- **Implementation**: Scanner interface requires network connectivity check
- **Server Verification**: Validation endpoint checks `is_scanned` flag before granting entry
- **UI Feedback**: Clear network status indicator and validation result display
- **Offline Tickets**: PDF tickets are static documents, validation requires online scanner

### Principle 3: Role-Based Access Control and Audit Trail ✅

- **Compliance**: Two roles defined - "Scanner" (read-only) and "Admin" (full access)
- **Implementation**: Role-based endpoint authorization via OAuth2 scopes
- **Audit Logging**: Separate `scan_event` table with immutable records
- **Scanner Restrictions**: Scanner role cannot access `/admin/*` endpoints
- **Audit Fields**: timestamp, device_id, user_id, ticket_id, validation_result

### Principle 4: Data Integrity for Pre-Registration and Walk-Ins ✅

- **Compliance**: Foreign key constraint linking tickets to IBMer host email
- **Implementation**: `host_email` field with validation and normalization
- **Email Normalization**: Lowercase, trim whitespace before storage
- **Atomic Operations**: CSV processing uses database transactions (commit all or rollback all)
- **Referential Integrity**: Database constraints prevent orphaned records

### Principle 5: Automated Ticket Distribution and Communication ✅

- **Compliance**: SendGrid API integration already exists
- **Implementation**: Email queue with retry logic (3 attempts: 1min, 5min, 15min)
- **Delivery Tracking**: `email_sent`, `email_sent_at`, `email_delivery_status` fields
- **PDF Generation**: Server-side PDF with embedded QR code
- **Email Template**: HTML template with event details, QR instructions, support contact
- **Alert System**: Failed deliveries flagged for admin review

### Technology Stack Constraints ✅

- **Compliance**: Built on CEN App Starter template
- **Backend**: FastAPI, SQLModel, PostgreSQL, Alembic, UV ✅
- **Frontend**: React 19, TypeScript, Vite, TanStack Router/Query, IBM Carbon ✅
- **Infrastructure**: Docker Compose (dev), OpenShift (prod) ✅
- **Authentication**: OAuth2 Proxy with IBM AppID ✅
- **Device Optimization**: Scanner UI touch-first, Admin UI keyboard-first

### Security and Privacy Requirements ✅

- **Compliance**: GDPR and IBM data protection policies
- **Personal Data**: Guest names, IBMer emails considered personal data
- **Data Retention**: 90-day retention policy (implementation deferred to future)
- **Access Logging**: All personal data access logged
- **QR Code Privacy**: Only ticket UUID in QR code (no personal data)
- **Database Encryption**: PostgreSQL encryption at rest (infrastructure level)
- **API Security**: Authentication and authorization on all endpoints

## Phase 0: Research & Clarification

### Research Tasks Completed

All technical unknowns have been resolved through analysis of existing codebase and documentation:

1. **QR Code Library Selection**
   - **Decision**: Use `qrcode` Python library with PIL backend
   - **Rationale**: Pure Python, well-maintained, simple API, PIL integration for image generation
   - **Alternatives Considered**: `python-qrcode`, `segno` (more complex, unnecessary features)

2. **PDF Generation Library**
   - **Decision**: Use `reportlab` library
   - **Rationale**: Industry standard, robust, excellent documentation, supports complex layouts
   - **Alternatives Considered**: `fpdf2` (simpler but less flexible), `WeasyPrint` (HTML-to-PDF, overkill)

3. **QR Scanning Frontend Library**
   - **Decision**: Use `html5-qrcode` npm package
   - **Rationale**: Pure JavaScript, no native dependencies, works on iOS/Android, active maintenance
   - **Alternatives Considered**: `@zxing/browser` (heavier, more complex), `jsqr` (lower-level)

4. **CSV Encoding Handling**
   - **Decision**: Use Python's `csv` module with `utf-8-sig` encoding
   - **Rationale**: Built-in, handles UTF-8 BOM automatically, robust error handling
   - **Alternatives Considered**: `pandas` (overkill for simple CSV), manual BOM stripping (error-prone)

5. **Database Locking Strategy**
   - **Decision**: Use PostgreSQL row-level locking with `SELECT ... FOR UPDATE`
   - **Rationale**: Prevents race conditions, built-in PostgreSQL feature, minimal performance impact
   - **Alternatives Considered**: Optimistic locking (requires retry logic), application-level locks (not distributed)

6. **Email Queue Implementation**
   - **Decision**: Use database-backed queue with background task processing
   - **Rationale**: Simple, reliable, no external dependencies, survives restarts
   - **Alternatives Considered**: Celery (overkill), Redis queue (additional infrastructure)

7. **Real-Time Dashboard Updates**
   - **Decision**: Use TanStack Query with polling (2-second interval)
   - **Rationale**: Simple, reliable, already in stack, no WebSocket complexity
   - **Alternatives Considered**: WebSockets (overkill), Server-Sent Events (more complex)

## Phase 1: Design Artifacts

**Note**: Due to file access restrictions in Architect mode, all design artifacts are embedded in this plan document rather than separate files.

### Data Model

#### Entity: Ticket

**Purpose**: Represents a single event entry permission with all guest information and validation state.

**Fields**:

- `id` (UUID, Primary Key): Globally unique ticket identifier
- `first_name` (String, Required): Guest first name (Vorname from CSV)
- `last_name` (String, Required): Guest last name (Nachname from CSV)
- `guest_email` (String, Required): Guest email address (normalized: lowercase, trimmed)
- `role` (String, Optional): Guest role designation (Rolle from CSV)
- `host_email` (String, Required): IBMer sponsor email (E-mail Host Gast from CSV, normalized)
- `guest_age` (String, Optional): Age category or value (Age Guest from CSV)
- `qr_code_data` (String, Required): QR code content (ticket UUID only)
- `is_scanned` (Boolean, Default: False): Validation status flag
- `scanned_at` (DateTime, Nullable): Timestamp of successful validation
- `scanner_device_id` (String, Nullable): Device that performed validation
- `scanner_user_id` (String, Nullable): User who performed validation
- `email_sent` (Boolean, Default: False): Email delivery attempt flag
- `email_sent_at` (DateTime, Nullable): Timestamp of successful email send
- `email_delivery_status` (Enum: pending/sent/failed/bounced): Current delivery state
- `email_retry_count` (Integer, Default: 0): Number of send attempts
- `created_at` (DateTime, Required): Ticket creation timestamp
- `updated_at` (DateTime, Required): Last modification timestamp

**Indexes**: `id` (primary), `is_scanned`, `email_delivery_status`, `host_email`, `created_at`

**Constraints**: `id` UNIQUE, email format validation

**Relationships**: One-to-Many with ScanEvent, One-to-One with EmailQueue

#### Entity: ScanEvent

**Purpose**: Immutable audit log of all ticket validation attempts.

**Fields**:

- `id` (UUID, Primary Key): Unique event identifier
- `ticket_id` (UUID, Foreign Key → Ticket.id): Reference to validated ticket
- `timestamp` (DateTime, Required): Exact time of scan attempt
- `scanner_device_id` (String, Required): Device identifier
- `scanner_user_id` (String, Required): Authenticated user performing scan
- `scan_result` (Enum: granted/already_scanned/invalid/network_error): Validation outcome
- `error_message` (String, Nullable): Error details if scan failed
- `network_latency_ms` (Integer, Nullable): Response time for monitoring

**Indexes**: `id` (primary), `ticket_id`, `timestamp`, `scanner_device_id`

**Constraints**: `ticket_id` FOREIGN KEY, INSERT-only (no updates/deletes)

**Relationships**: Many-to-One with Ticket

#### Entity: EmailQueue

**Purpose**: Background job queue for reliable email delivery with retry logic.

**Fields**:

- `id` (UUID, Primary Key): Unique queue entry identifier
- `ticket_id` (UUID, Foreign Key → Ticket.id): Reference to ticket being sent
- `recipient_email` (String, Required): Destination email address
- `subject` (String, Required): Email subject line
- `html_body` (Text, Required): HTML email content
- `pdf_attachment_path` (String, Required): Path to generated PDF ticket
- `status` (Enum: pending/processing/sent/failed): Current job state
- `retry_count` (Integer, Default: 0): Number of send attempts (max 3)
- `next_retry_at` (DateTime, Nullable): Scheduled retry time (exponential backoff)
- `last_error` (Text, Nullable): Most recent error message
- `created_at` (DateTime, Required): Queue entry creation time
- `processed_at` (DateTime, Nullable): Successful send timestamp

**Indexes**: `id` (primary), `status`, `next_retry_at`, `ticket_id`

**Constraints**: `ticket_id` FOREIGN KEY, `retry_count` <= 3

**Relationships**: One-to-One with Ticket

### API Contracts

**Key Endpoints**:

#### POST /api/v1/tickets/upload-csv

**Purpose**: Bulk ticket generation from CSV file upload

**Request**:

- Content-Type: `multipart/form-data`
- Body: `file` (CSV file with semicolon delimiter, UTF-8 BOM encoding)

**Response**:

```json
{
  "tickets_created": 100,
  "tickets_failed": 2,
  "errors": [
    { "row": 5, "error": "Missing required field: first_name" },
    { "row": 12, "error": "Invalid email format" }
  ]
}
```

#### POST /api/v1/tickets/validate

**Purpose**: Real-time QR code validation for entry control

**Request**:

```json
{
  "ticket_id": "uuid-string",
  "scanner_device_id": "device-identifier",
  "scanner_user_id": "user-id"
}
```

**Response**:

```json
{
  "result": "granted|already_scanned|invalid|network_error",
  "ticket": {
    "id": "uuid",
    "first_name": "Max",
    "last_name": "Mustermann",
    "scanned_at": "2026-05-04T17:30:00Z"
  },
  "message": "Entry Granted"
}
```

#### GET /api/v1/tickets/dashboard

**Purpose**: Real-time statistics for monitoring

**Response**:

```json
{
  "total_tickets": 500,
  "scanned_tickets": 342,
  "remaining_tickets": 158,
  "scan_rate_per_minute": 12.5
}
```

#### GET /api/v1/tickets/{ticket_id}/pdf

**Purpose**: Download generated ticket PDF

**Response**: Binary PDF file with Content-Disposition header

#### POST /api/v1/tickets/resend-email/{ticket_id}

**Purpose**: Retry failed email delivery

**Response**:

```json
{
  "success": true,
  "message": "Email queued for retry"
}
```

### Frontend Routes

- `/admin/tickets/upload` - CSV upload interface (Admin only)
- `/admin/tickets/dashboard` - Statistics and monitoring (Admin only)
- `/scanner` - QR code scanning interface (Scanner role)
- `/admin/tickets/{id}` - Individual ticket details (Admin only)

### Development Setup (Quickstart)

**Prerequisites**:

- Docker Desktop or compatible container runtime
- Node.js 20+ and npm
- Python 3.12+ with UV package manager

**Initial Setup**:

```bash
# 1. Install backend dependencies
cd backend && uv sync

# 2. Install frontend dependencies
cd frontend && npm install

# 3. Start development environment
docker compose watch

# 4. Run database migrations
cd backend && source .venv/bin/activate
alembic upgrade head

# 5. Access application
# Frontend: http://localhost:5173
# Backend API: http://localhost:8000
# API Docs: http://localhost:8000/docs
```

**Testing CSV Upload**:

```bash
# Use the provided sample CSV
curl -X POST http://localhost:8000/api/v1/tickets/upload-csv \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "file=@Registrierungen_Airtable (1).csv"
```

**Testing QR Validation**:

1. Open scanner interface at http://localhost:5173/scanner
2. Allow camera access
3. Scan generated QR code from ticket PDF
4. Verify validation result displayed

## Phase 2: Implementation Phases

### Phase 2.1: Database Schema and Models

**Duration**: 1 day  
**Dependencies**: None

**Tasks**:

1. Create Alembic migration for `ticket`, `scan_event`, `email_queue` tables
2. Define SQLModel table classes in `backend/app/tables.py`
3. Define Pydantic API schemas in `backend/app/models.py`
4. Add database indexes for performance (ticket_id, is_scanned, email_sent)
5. Test migration up/down with sample data

**Deliverables**:

- Migration file: `backend/app/alembic/versions/xxx_add_ticket_tables.py`
- Table models: `Ticket`, `ScanEvent`, `EmailQueue` in `tables.py`
- API schemas: `TicketCreate`, `TicketPublic`, `ScanEventPublic` in `models.py`

### Phase 2.2: CSV Processing and Ticket Generation (User Story 1)

**Duration**: 2 days  
**Dependencies**: Phase 2.1

**Tasks**:

1. Add `qrcode` and `reportlab` to `backend/pyproject.toml`
2. Create CSV parser with UTF-8 BOM handling in `backend/app/utils/csv_parser.py`
3. Create QR code generator utility in `backend/app/utils/qr_generator.py`
4. Create PDF ticket generator in `backend/app/utils/pdf_generator.py`
5. Implement CRUD operations in `backend/app/crud.py` for tickets
6. Create upload endpoint in `backend/app/api/routes/tickets.py`
7. Add email queue insertion after ticket creation
8. Write unit tests for CSV parsing, QR generation, PDF generation

**Deliverables**:

- `POST /api/v1/tickets/upload-csv` endpoint
- CSV validation with error reporting
- Ticket generation with UUID and QR code
- PDF generation with embedded QR code
- Email queue entries created

### Phase 2.3: Email Distribution System

**Duration**: 1.5 days  
**Dependencies**: Phase 2.2

**Tasks**:

1. Create email template with event details and QR instructions
2. Implement background email processor in `backend/app/workers/email_worker.py`
3. Add retry logic with exponential backoff (1min, 5min, 15min)
4. Integrate with existing SendGrid endpoint
5. Update email queue status tracking
6. Create admin endpoint to retry failed emails
7. Add email delivery status to ticket API responses

**Deliverables**:

- Email template with embedded PDF attachment
- Background worker processing email queue
- Retry logic with exponential backoff
- `POST /api/v1/tickets/resend-email/{ticket_id}` endpoint
- Email delivery status tracking

### Phase 2.4: QR Code Validation System (User Story 2)

**Duration**: 2 days  
**Dependencies**: Phase 2.1

**Tasks**:

1. Create validation endpoint with row-level locking in `backend/app/api/routes/tickets.py`
2. Implement scan event logging in CRUD operations
3. Add concurrent scan prevention logic
4. Create scanner frontend route in `frontend/src/routes/_layout/scanner.tsx`
5. Integrate `html5-qrcode` library for camera access
6. Implement validation result display (green/red/yellow states)
7. Add network connectivity check
8. Write integration tests for concurrent scanning

**Deliverables**:

- `POST /api/v1/tickets/validate` endpoint with locking
- Scanner UI with camera access
- Real-time validation feedback
- Network status indicator
- Scan event audit logging

### Phase 2.5: Dashboard and Monitoring (User Story 3)

**Duration**: 1.5 days  
**Dependencies**: Phase 2.1, Phase 2.4

**Tasks**:

1. Create dashboard statistics endpoint in `backend/app/api/routes/tickets.py`
2. Implement real-time query for ticket counts
3. Create recent scan activity endpoint
4. Build dashboard UI in `frontend/src/routes/_layout/admin/dashboard.tsx`
5. Integrate TanStack Query with 2-second polling
6. Add Carbon Data Table for recent scans
7. Add Carbon Tile components for statistics

**Deliverables**:

- `GET /api/v1/tickets/dashboard` endpoint
- `GET /api/v1/tickets/recent-scans` endpoint
- Dashboard UI with real-time updates
- Statistics tiles (total, scanned, remaining)
- Recent scan activity table

### Phase 2.6: Admin Features and PDF Download

**Duration**: 1 day  
**Dependencies**: Phase 2.2

**Tasks**:

1. Create ticket list endpoint with pagination
2. Create individual ticket detail endpoint
3. Create PDF download endpoint
4. Build ticket list UI in `frontend/src/routes/_layout/admin/tickets.tsx`
5. Add ticket detail modal/page
6. Implement PDF download functionality
7. Add search and filter capabilities

**Deliverables**:

- `GET /api/v1/tickets` endpoint with pagination
- `GET /api/v1/tickets/{ticket_id}` endpoint
- `GET /api/v1/tickets/{ticket_id}/pdf` endpoint
- Ticket list UI with search/filter
- Ticket detail view
- PDF download functionality

### Phase 2.7: Testing and Edge Case Handling

**Duration**: 2 days  
**Dependencies**: All previous phases

**Tasks**:

1. Test CSV with non-ASCII characters (ä, ö, ü, ß)
2. Test CSV with inconsistent column counts
3. Test concurrent scanning race conditions
4. Test damaged/unreadable QR codes
5. Test large CSV files (10,000+ rows)
6. Test email address normalization
7. Test network failure during validation
8. Test different CSV encodings
9. Test trailing spaces in CSV fields
10. Load testing with multiple scanners

**Deliverables**:

- Comprehensive test suite
- Edge case handling documentation
- Performance benchmarks
- Bug fixes for discovered issues

## Phase 3: Deployment Preparation

### Phase 3.1: Documentation

**Duration**: 0.5 days

**Tasks**:

1. Update README with feature documentation
2. Create user guide for CSV upload
3. Create scanner operation guide
4. Document email configuration
5. Add troubleshooting guide

### Phase 3.2: Production Configuration

**Duration**: 0.5 days

**Tasks**:

1. Configure SendGrid domain authentication
2. Set up production environment variables
3. Configure database backups
4. Set up monitoring and alerts
5. Configure rate limiting

## Timeline Summary

**Total Estimated Duration**: 11.5 days

- Phase 2.1: Database Schema (1 day)
- Phase 2.2: CSV Processing (2 days)
- Phase 2.3: Email Distribution (1.5 days)
- Phase 2.4: QR Validation (2 days)
- Phase 2.5: Dashboard (1.5 days)
- Phase 2.6: Admin Features (1 day)
- Phase 2.7: Testing (2 days)
- Phase 3: Deployment (1 day)

**Critical Path**: Phase 2.1 → Phase 2.2 → Phase 2.4 → Phase 2.7

**Parallel Work Opportunities**:

- Phase 2.3 (Email) can start after Phase 2.2
- Phase 2.5 (Dashboard) can start after Phase 2.1 and Phase 2.4
- Phase 2.6 (Admin) can start after Phase 2.2

## Risk Assessment

### High Risk

- **Concurrent Scanning Race Conditions**: Mitigated by row-level locking and comprehensive testing
- **Email Deliverability**: Mitigated by SendGrid domain authentication and retry logic
- **CSV Encoding Issues**: Mitigated by UTF-8 BOM handling and validation

### Medium Risk

- **QR Code Scanning Reliability**: Mitigated by library selection and testing in various lighting
- **Large CSV Performance**: Mitigated by batch processing and progress feedback
- **Network Connectivity**: Mitigated by clear UI feedback and error handling

### Low Risk

- **PDF Generation**: Standard library with proven track record
- **Database Performance**: PostgreSQL handles expected load easily
- **Frontend Responsiveness**: Carbon Design System provides optimized components

## Success Metrics

- ✅ CSV processing: 500 rows in <30 seconds
- ✅ Validation latency: <2 seconds
- ✅ Dashboard updates: <2 seconds
- ✅ QR scan success: 95% first attempt
- ✅ Concurrent scanners: 5+ devices
- ✅ Duplicate prevention: 100% accuracy
- ✅ Audit trail: 100% completeness
- ✅ Email delivery: 95% success rate

## Next Steps

1. **Generate Tasks**: Run `/bobkit.tasks` to create detailed task breakdown
2. **Review Plan**: Stakeholder review and approval
3. **Begin Implementation**: Start with Phase 2.1 (Database Schema)
4. **Continuous Testing**: Test each phase before proceeding
5. **Documentation**: Update docs as features are completed
