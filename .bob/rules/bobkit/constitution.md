<!--
Sync Impact Report:
- Version: 1.0.0 (Initial Constitution)
- Ratification Date: 2026-05-04
- Principles Defined: 5 core principles for IBM Event App
- Templates Status:
  ✅ .specify/templates/bobkit/plan-template.md - Reviewed, no updates needed (initial creation)
  ✅ .specify/templates/bobkit/spec-template.md - Reviewed, no updates needed (initial creation)
  ✅ .specify/templates/bobkit/tasks-template.md - Reviewed, no updates needed (initial creation)
  ✅ .specify/templates/bobkit/commands/*.md - Reviewed, no updates needed (initial creation)
- Follow-up TODOs: None
-->

# IBM Event App Constitution

## Core Principles

### Principle 1: Ticket Uniqueness and Validation Integrity

**Every ticket MUST be uniquely identifiable and validated exactly once.**

- Each ticket generated receives a globally unique identifier (UUID or equivalent)
- QR codes/barcodes MUST encode the unique ticket ID
- Database MUST enforce uniqueness constraints on ticket IDs
- Validation system MUST prevent duplicate scans of the same ticket
- Validation state (scanned/not scanned) MUST be persisted immediately upon successful scan
- Network failures during validation MUST NOT result in duplicate entries or lost validation states

**Rationale**: The core business requirement is preventing unauthorized entry and ensuring each ticket is used only once. Duplicate ticket usage would compromise event security and capacity management. Immediate persistence prevents race conditions when multiple scanning devices operate simultaneously.

### Principle 2: Real-Time Validation and Duplicate Prevention

**Ticket validation MUST occur in real-time with immediate server verification.**

- Scanning devices (iPads/iPhones) MUST have active network connectivity during event operations
- Each ticket scan MUST immediately query the server to check validation status
- Server MUST respond with validation result (valid/already-scanned/invalid) before entry is granted
- Duplicate scans MUST be prevented through real-time database checks
- User interface MUST clearly indicate network connectivity status and validation results
- Attendee tickets (PDF with QR/barcode) are offline documents that do not require connectivity

**Rationale**: Real-time validation is essential to prevent duplicate ticket usage across multiple scanning devices. Without immediate server verification, the same ticket could be scanned simultaneously on different devices, compromising event security. The PDF tickets themselves are offline documents that attendees can access without connectivity, but the validation process requires online scanning devices.

### Principle 3: Role-Based Access Control and Audit Trail

**System MUST enforce strict role separation and maintain complete audit logs.**

- Two distinct user roles: "Ticket Scanner" (read-only validation) and "Registration Admin" (create/modify registrations)
- Scanner role MUST NOT have access to registration modification functions
- Admin role MUST NOT bypass validation rules when creating walk-in registrations
- All ticket validations MUST be logged with: timestamp, device ID, user ID, ticket ID, validation result
- All registration modifications MUST be logged with: timestamp, user ID, IBMer name, attendee details, action type
- Audit logs MUST be immutable and tamper-evident

**Rationale**: Clear role separation prevents accidental or malicious data modification during high-pressure event operations. Complete audit trails enable post-event analysis, dispute resolution, and compliance verification. Immutability ensures accountability.

### Principle 4: Data Integrity for Pre-Registration and Walk-Ins

**Registration data MUST maintain referential integrity between IBMers and their guests.**

- Each registration MUST link to exactly one IBMer (sponsor)
- IBMer email addresses MUST be validated and normalized
- Guest names MUST be captured with sufficient detail for identification
- Walk-in registrations MUST capture the same data fields as pre-registrations
- Database constraints MUST prevent orphaned registrations or invalid IBMer references
- Bulk ticket generation MUST be atomic (all succeed or all fail)

**Rationale**: The event's business model requires tracking which IBMer sponsored each attendee. This enables capacity planning per IBMer, post-event communication, and compliance with IBM's guest policies. Atomic operations prevent partial failures that would require manual cleanup.

### Principle 5: Automated Ticket Distribution and Communication

**Ticket delivery MUST be automated, reliable, and traceable.**

- Tickets MUST be generated as PDF attachments with embedded QR/barcode
- Email delivery MUST use a designated IBM Outlook account with proper authentication
- Email sending MUST be queued and retried on transient failures
- Delivery status (sent/failed/bounced) MUST be tracked per ticket
- Failed deliveries MUST trigger alerts for manual intervention
- Email templates MUST include clear event details, QR code instructions, and support contact

**Rationale**: Manual ticket distribution for potentially hundreds of attendees is error-prone and time-consuming. Automated delivery ensures timely receipt, reduces organizer workload, and provides delivery confirmation. Retry logic handles temporary email server issues without losing tickets.

## Technology Stack Constraints

**The application MUST be built on the CEN App Starter template with the following stack:**

- **Backend**: FastAPI, SQLModel, PostgreSQL, Alembic migrations, UV package manager
- **Frontend**: React 19, TypeScript, Vite, TanStack Router/Query, IBM Carbon Design System
- **Infrastructure**: Docker Compose for development, OpenShift for production deployment
- **Authentication**: OAuth2 Proxy with IBM AppID (production) or local auth (development)

**Device Requirements**:
- Scanner interface MUST be optimized for iPad/iPhone (touch-first, camera access)
- Admin interface MUST be usable on MacBook (keyboard-first, larger screen)
- Both interfaces MUST support dark mode for varying lighting conditions

**Rationale**: The CEN App Starter provides proven patterns for IBM deployments, including security, compliance, and operational requirements. Device-specific optimization ensures usability in the actual event environment (handheld scanning vs. desk-based registration).

## Security and Privacy Requirements

**Personal data MUST be handled in compliance with IBM data protection policies.**

- Guest names and IBMer email addresses are considered personal data
- Data retention policy: Event data MUST be retained for 90 days post-event, then archived or deleted
- Access to personal data MUST be logged and restricted to authorized personnel
- Ticket QR codes MUST NOT encode personal information (only ticket UUID)
- Database MUST encrypt sensitive fields at rest
- API endpoints MUST enforce authentication and authorization on all operations

**Rationale**: IBM events involve employee and guest personal data subject to GDPR and IBM's internal policies. Minimal data exposure (QR codes contain only IDs) reduces privacy risk. Encryption and access controls protect against unauthorized disclosure.

## Governance

**This constitution supersedes all other development practices and decisions.**

- All feature specifications MUST be validated against these principles before implementation
- Any deviation from constitutional principles MUST be explicitly documented and justified
- Amendments to this constitution require:
  1. Written proposal with rationale
  2. Review by project stakeholders
  3. Version increment following semantic versioning
  4. Update of all dependent templates and documentation
- Complexity that violates principles MUST be justified or refactored
- Code reviews MUST verify constitutional compliance

**Amendment Procedure**:
1. Propose amendment with clear rationale and impact analysis
2. Update constitution with new version number (MAJOR for breaking changes, MINOR for additions, PATCH for clarifications)
3. Propagate changes to all BobKit templates (plan, spec, tasks, checklists)
4. Update AGENTS.md and other guidance documents
5. Commit with message: `docs: amend constitution to vX.Y.Z (description)`

**Compliance Review**:
- Every feature specification MUST include a "Constitutional Compliance" section
- Every implementation plan MUST validate against principles
- Every pull request MUST confirm no principle violations

**Version**: 1.0.0 | **Ratified**: 2026-05-04 | **Last Amended**: 2026-05-04