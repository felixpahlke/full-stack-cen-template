# Tasks: CSV-Based Ticket Generation and Validation

**Input**: Design documents from `/specs/001-ticket-generation-validation/`
**Prerequisites**: plan.md (required), spec.md (required for user stories)

**Tests**: Tests are NOT explicitly requested in the specification, so test tasks are omitted.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Web app**: `backend/app/`, `frontend/src/`
- Backend routes: `backend/app/api/routes/`
- Backend models: `backend/app/tables.py` (SQLModel), `backend/app/models.py` (Pydantic)
- Frontend routes: `frontend/src/routes/_layout/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and dependency installation

- [x] T001 Add `qrcode` library to backend/pyproject.toml dependencies
- [x] T002 Add `reportlab` library to backend/pyproject.toml dependencies
- [x] T003 [P] Add `html5-qrcode` npm package to frontend/package.json
- [x] T004 [P] Run `cd backend && uv sync` to install Python dependencies
- [x] T005 [P] Run `cd frontend && npm install` to install frontend dependencies

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T006 Create Alembic migration for `ticket`, `scan_event`, `email_queue` tables in backend/app/alembic/versions/
- [x] T007 Define `Ticket` SQLModel table class in backend/app/tables.py with fields: id (UUID), first_name, last_name, guest_email, role, host_email, guest_age, qr_code_data, is_scanned, scanned_at, scanner_device_id, scanner_user_id, email_sent, email_sent_at, email_delivery_status, email_retry_count, created_at, updated_at
- [x] T008 [P] Define `ScanEvent` SQLModel table class in backend/app/tables.py with fields: id (UUID), ticket_id (FK), timestamp, scanner_device_id, scanner_user_id, scan_result (enum), error_message, network_latency_ms
- [x] T009 [P] Define `EmailQueue` SQLModel table class in backend/app/tables.py with fields: id (UUID), ticket_id (FK), recipient_email, subject, html_body, pdf_attachment_path, status (enum), retry_count, next_retry_at, last_error, created_at, processed_at
- [x] T010 Define Pydantic API schemas in backend/app/models.py: TicketCreate, TicketUpdate, TicketPublic, ScanEventPublic, EmailQueuePublic
- [x] T011 Add database indexes in migration: ticket.id (primary), ticket.is_scanned, ticket.email_delivery_status, ticket.host_email, ticket.created_at, scan_event.ticket_id, scan_event.timestamp, email_queue.status, email_queue.next_retry_at
- [x] T012 Run migration: `cd backend && source .venv/bin/activate && alembic upgrade head`
- [x] T013 Test migration rollback: `alembic downgrade -1` and re-upgrade to verify schema

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Bulk Ticket Generation from CSV (Priority: P1) 🎯 MVP

**Goal**: Enable administrators to upload CSV files and generate tickets with QR codes for all guests

**Independent Test**: Upload a CSV file with sample guest data and verify that tickets are created in the database with unique IDs and QR codes. Check that PDF tickets are generated with embedded QR codes.

### Implementation for User Story 1

- [x] T014 [P] [US1] Create CSV parser utility in backend/app/utils/csv_parser.py with UTF-8 BOM handling, semicolon delimiter, field validation (first_name, last_name, email required)
- [x] T015 [P] [US1] Create QR code generator utility in backend/app/utils/qr_generator.py using `qrcode` library to encode ticket UUID
- [x] T016 [P] [US1] Create PDF ticket generator in backend/app/utils/pdf_generator.py using `reportlab` to embed QR code, guest name, event details, ticket ID
- [x] T017 [US1] Implement ticket CRUD operations in backend/app/crud.py: create_ticket, get_ticket_by_id, get_tickets_paginated, update_ticket
- [x] T018 [US1] Create tickets router file backend/app/api/routes/tickets.py and register in backend/app/api/main.py
- [x] T019 [US1] Implement POST /api/v1/tickets/upload-csv endpoint in backend/app/api/routes/tickets.py with multipart/form-data handling, CSV parsing, ticket generation, email queue insertion
- [x] T020 [US1] Add email normalization (lowercase, trim) in CSV parser before ticket creation
- [x] T021 [US1] Add validation error reporting for invalid CSV rows without halting processing of valid rows
- [x] T022 [US1] Add row-level transaction handling (individual row failures don't affect other rows)
- [x] T023 [US1] Create email queue entries after successful ticket generation in upload-csv endpoint
- [x] T024 [US1] Create CSV upload UI component in frontend/src/components/tickets/UploadCSV.tsx using Carbon FileUploader
- [x] T025 [US1] Create admin tickets upload route in frontend/src/routes/\_layout/admin/tickets/upload.tsx
- [x] T026 [US1] Add upload route to header navigation in frontend/src/components/common/Header.tsx
- [x] T027 [US1] Integrate upload UI with POST /api/v1/tickets/upload-csv endpoint using TanStack Query mutation
- [x] T028 [US1] Display upload results (tickets_created, tickets_failed, errors) in UI with Carbon InlineNotification

**Checkpoint**: At this point, User Story 1 should be fully functional - administrators can upload CSV files and generate tickets with QR codes

---

## Phase 3.1: Critical Bug Fixes (Code Review Remediation)

**Purpose**: Fix critical issues discovered during code review that prevent User Story 1 from functioning

**⚠️ BLOCKING**: These issues MUST be fixed before User Story 1 can be considered complete

- [x] T028a [CRITICAL] Fix field name bug in backend/app/crud.py:120-121 - Change `scanned_by_device` to `scanner_device_id` and `scanned_by_user` to `scanner_user_id` in mark_ticket_scanned function
- [x] T028b [CRITICAL] Add row-level locking to validation endpoint in backend/app/api/routes/tickets.py:222 - Use `SELECT ... FOR UPDATE` to prevent race conditions (Constitution Principle 2)
- [x] T028c [CRITICAL] Verify database migration was executed - Run `cd backend && source .venv/bin/activate && alembic current` to check current revision matches 86a64c80a5e2
- [x] T028d [HIGH] Regenerate frontend TypeScript client - Run `./scripts/generate-client.sh` from repo root to ensure type safety
- [x] T028e [MEDIUM] Fix email queue PDF path - Replace hardcoded `/tmp/ticket_{ticket.id}.pdf` placeholder with actual PDF generation or document as deferred to Phase 6 (documented as TODO for Phase 6)
- [x] T028f [MEDIUM] Add proper logging for email queue errors in backend/app/api/routes/tickets.py:91-103 - Replace print statements with logger

**Checkpoint**: After these fixes, User Story 1 will be fully functional and constitution-compliant

---

## Phase 4: User Story 2 - Real-Time Ticket Validation via QR Scan (Priority: P2)

**Goal**: Enable ticket scanners to validate QR codes in real-time and prevent duplicate entries

**Independent Test**: Generate test tickets, scan their QR codes with a mobile device, and verify that the first scan succeeds while subsequent scans are rejected. Test concurrent scanning from multiple devices.

### Implementation for User Story 2

- [x] T029 [US2] Implement POST /api/v1/tickets/validate endpoint in backend/app/api/routes/tickets.py with row-level locking using `SELECT ... FOR UPDATE`
- [x] T030 [US2] Add scan event logging in validate endpoint: create ScanEvent record with timestamp, device_id, user_id, scan_result
- [x] T031 [US2] Implement concurrent scan prevention logic: check is_scanned flag within locked transaction before granting entry
- [x] T032 [US2] Add validation result responses: granted (200), already_scanned (409), invalid (404), network_error (503)
- [x] T033 [US2] Create scanner route in frontend/src/routes/\_layout/scanner.tsx with touch-optimized UI for iPad/iPhone
- [x] T034 [US2] Integrate `html5-qrcode` library in scanner component for camera access and QR scanning
- [x] T035 [US2] Implement validation result display with color-coded feedback: green (Entry Granted), red (Already Scanned/Invalid), yellow (Network Error)
- [x] T036 [US2] Add network connectivity check in scanner UI with status indicator
- [x] T037 [US2] Add device ID generation/storage in browser localStorage for scanner_device_id tracking
- [x] T038 [US2] Integrate scanner UI with POST /api/v1/tickets/validate endpoint using TanStack Query mutation
- [x] T039 [US2] Add scanner route to header navigation in frontend/src/components/common/Header.tsx
- [x] T040 [US2] Add audio/haptic feedback for successful/failed scans in scanner UI

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently - tickets can be generated and validated in real-time

---

## Phase 5: User Story 3 - Ticket Status Monitoring Dashboard (Priority: P3)

**Goal**: Provide administrators with real-time visibility into ticket statistics and scan activity

**Independent Test**: Generate tickets, scan some of them, and verify that the dashboard displays accurate counts and updates in real-time without page refresh.

### Implementation for User Story 3

- [x] T041 [US3] Implement GET /api/v1/tickets/dashboard endpoint in backend/app/api/routes/tickets.py returning: total_tickets, scanned_tickets, remaining_tickets, scan_rate_per_minute
- [x] T042 [US3] Implement GET /api/v1/tickets/recent-scans endpoint in backend/app/api/routes/tickets.py returning last 50 scan events with ticket details
- [x] T043 [US3] Create dashboard route in frontend/src/routes/\_layout/admin/dashboard.tsx
- [x] T044 [US3] Create dashboard statistics component in frontend/src/components/tickets/DashboardStats.tsx using Carbon Tile components
- [x] T045 [US3] Create recent scans table component in frontend/src/components/tickets/RecentScansTable.tsx using Carbon DataTable
- [x] T046 [US3] Integrate dashboard with GET /api/v1/tickets/dashboard endpoint using TanStack Query with 2-second polling interval
- [x] T047 [US3] Integrate recent scans table with GET /api/v1/tickets/recent-scans endpoint using TanStack Query with 2-second polling interval
- [x] T048 [US3] Add dashboard route to header navigation in frontend/src/components/common/Header.tsx
- [x] T049 [US3] Add auto-refresh indicator in dashboard UI to show real-time updates

**Checkpoint**: All user stories should now be independently functional - full ticket lifecycle from generation to validation to monitoring

---

## Phase 6: Email Distribution System

**Purpose**: Automated ticket delivery via email with retry logic

**Dependencies**: Phase 3 (User Story 1) must be complete

- [ ] T050 [P] Create email template HTML in backend/app/templates/ticket_email.html with event details, QR instructions, support contact
- [ ] T051 [P] Create email worker module in backend/app/workers/email_worker.py with background processing logic
- [ ] T052 Implement email queue processor in email_worker.py: fetch pending emails, send via SendGrid, update status, handle retries
- [ ] T053 Add exponential backoff retry logic in email_worker.py: 1min, 5min, 15min delays with max 3 attempts
- [ ] T054 Integrate with existing SendGrid endpoint at backend/app/api/routes/mail.py for email sending
- [ ] T055 Update email queue status tracking: pending → processing → sent/failed
- [ ] T056 Implement POST /api/v1/tickets/resend-email/{ticket_id} endpoint in backend/app/api/routes/tickets.py
- [ ] T057 Add email delivery status to ticket API responses (TicketPublic schema)
- [ ] T058 Create background task scheduler to run email_worker.py periodically (every 30 seconds)
- [ ] T059 Add failed email alert logging for administrator review

---

## Phase 7: Admin Features and PDF Download

**Purpose**: Additional administrative capabilities for ticket management

**Dependencies**: Phase 3 (User Story 1) must be complete

- [ ] T060 [P] Implement GET /api/v1/tickets endpoint in backend/app/api/routes/tickets.py with pagination, search, filter by host_email, is_scanned, email_delivery_status
- [ ] T061 [P] Implement GET /api/v1/tickets/{ticket_id} endpoint in backend/app/api/routes/tickets.py returning full ticket details
- [ ] T062 [P] Implement GET /api/v1/tickets/{ticket_id}/pdf endpoint in backend/app/api/routes/tickets.py returning PDF file with Content-Disposition header
- [ ] T063 Create ticket list route in frontend/src/routes/\_layout/admin/tickets/index.tsx
- [ ] T064 Create ticket list component in frontend/src/components/tickets/TicketList.tsx using Carbon DataTable with pagination
- [ ] T065 Add search and filter controls in ticket list UI: search by name/email, filter by scan status, filter by email status
- [ ] T066 Create ticket detail modal component in frontend/src/components/tickets/TicketDetail.tsx
- [ ] T067 Add PDF download button in ticket detail modal calling GET /api/v1/tickets/{ticket_id}/pdf
- [ ] T068 Add ticket list route to header navigation in frontend/src/components/common/Header.tsx
- [ ] T069 Integrate ticket list with GET /api/v1/tickets endpoint using TanStack Query with pagination

---

## Phase 8: Edge Case Handling and Validation

**Purpose**: Robust handling of edge cases and error conditions

**Dependencies**: All previous phases

- [ ] T070 [P] Add non-ASCII character handling test in CSV parser (ä, ö, ü, ß) and verify correct storage/retrieval
- [ ] T071 [P] Add CSV validation for inconsistent column counts with clear error messages
- [ ] T072 [P] Add trailing whitespace trimming in CSV parser for all fields
- [ ] T073 [P] Add email format validation in CSV parser with error reporting
- [ ] T074 Test concurrent scanning race conditions with 5+ simultaneous devices and verify only one scan succeeds
- [ ] T075 Add QR code error handling for damaged/unreadable codes in scanner UI
- [ ] T076 Test large CSV file processing (1000+ rows) and verify performance meets <30 second requirement
- [ ] T077 Add network failure handling in validation endpoint with appropriate error responses
- [ ] T078 Test different CSV encodings (UTF-8, UTF-8 BOM, ISO-8859-1) and add encoding detection if needed
- [ ] T079 Add validation for empty/null values in optional CSV fields (role, guest_age)
- [ ] T080 Add rate limiting to upload-csv endpoint to prevent abuse

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T081 [P] Update README.md with feature documentation, CSV format specification, setup instructions
- [ ] T082 [P] Create user guide for CSV upload in docs/csv-upload-guide.md
- [ ] T083 [P] Create scanner operation guide in docs/scanner-guide.md
- [ ] T084 [P] Add troubleshooting guide in docs/troubleshooting.md
- [ ] T085 Add logging for all ticket operations (creation, validation, email sending) with appropriate log levels
- [ ] T086 Add error handling middleware for consistent API error responses
- [ ] T087 Regenerate frontend API client: `./scripts/generate-client.sh`
- [ ] T088 Code cleanup and refactoring: remove unused imports, standardize naming conventions
- [ ] T089 Add API documentation comments for all endpoints in backend/app/api/routes/tickets.py
- [ ] T090 Security review: verify authentication on all endpoints, check for SQL injection vulnerabilities, validate input sanitization

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - User Story 1 (P1): Can start after Foundational - No dependencies on other stories
  - User Story 2 (P2): Can start after Foundational - No dependencies on other stories (independent validation system)
  - User Story 3 (P3): Can start after Foundational - No dependencies on other stories (reads from same database)
- **Email Distribution (Phase 6)**: Depends on User Story 1 (ticket generation)
- **Admin Features (Phase 7)**: Depends on User Story 1 (ticket generation)
- **Edge Cases (Phase 8)**: Depends on all previous phases being complete
- **Polish (Phase 9)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - Independent validation system, no dependency on US1
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - Reads from database, no dependency on US1/US2

### Within Each User Story

- Models before services
- Services before endpoints
- Backend endpoints before frontend integration
- Core implementation before UI polish
- Story complete before moving to next priority

### Parallel Opportunities

- **Phase 1 (Setup)**: All tasks marked [P] can run in parallel (T001-T005)
- **Phase 2 (Foundational)**: Tasks T008-T009 can run in parallel with T007
- **Phase 3 (US1)**: Tasks T014-T016 can run in parallel (different utilities)
- **Phase 5 (US3)**: Tasks T041-T042 can run in parallel (different endpoints)
- **Phase 6 (Email)**: Tasks T050-T051 can run in parallel (template and worker)
- **Phase 7 (Admin)**: Tasks T060-T062 can run in parallel (different endpoints)
- **Phase 8 (Edge Cases)**: Tasks T070-T073 can run in parallel (different validations)
- **Phase 9 (Polish)**: Tasks T081-T084 can run in parallel (different documentation)
- **Once Foundational completes**: User Stories 1, 2, and 3 can all start in parallel (if team capacity allows)

---

## Parallel Example: User Story 1

```bash
# Launch all utility modules for User Story 1 together:
Task T014: "Create CSV parser utility in backend/app/utils/csv_parser.py"
Task T015: "Create QR code generator utility in backend/app/utils/qr_generator.py"
Task T016: "Create PDF ticket generator in backend/app/utils/pdf_generator.py"

# These can all be developed simultaneously as they have no dependencies on each other
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T005)
2. Complete Phase 2: Foundational (T006-T013) - CRITICAL - blocks all stories
3. Complete Phase 3: User Story 1 (T014-T028)
4. **STOP and VALIDATE**: Test User Story 1 independently - upload CSV, verify tickets generated with QR codes
5. Deploy/demo if ready - administrators can now generate tickets

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP! - ticket generation works)
3. Add User Story 2 → Test independently → Deploy/Demo (validation works)
4. Add User Story 3 → Test independently → Deploy/Demo (monitoring works)
5. Add Email Distribution (Phase 6) → Test independently → Deploy/Demo (automated delivery works)
6. Add Admin Features (Phase 7) → Test independently → Deploy/Demo (full admin capabilities)
7. Each phase adds value without breaking previous functionality

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together (T001-T013)
2. Once Foundational is done:
   - Developer A: User Story 1 (T014-T028) - CSV upload and ticket generation
   - Developer B: User Story 2 (T029-T040) - QR scanning and validation
   - Developer C: User Story 3 (T041-T049) - Dashboard and monitoring
3. Stories complete and integrate independently
4. Team reconvenes for Email Distribution (Phase 6) and Admin Features (Phase 7)

---

## Notes

- [P] tasks = different files, no dependencies, can run in parallel
- [Story] label maps task to specific user story for traceability (US1, US2, US3)
- Each user story should be independently completable and testable
- Tests are NOT included as they were not explicitly requested in the specification
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Run `./scripts/generate-client.sh` after backend API changes to update frontend TypeScript client
- Use `docker compose watch` for hot-reload development environment
- Run `alembic upgrade head` after creating new migrations
