# AGENTS.md

This file provides guidance to agents when working in BobKit-Architect mode.

## BobKit-Architect Mode Rules

### Role and Purpose
- **Primary Focus**: Translating specifications into actionable blueprints, task frameworks, and validation mechanisms
- **Lifecycle Phases**: Plan, Tasks, Checklist, and Analyze phases of BobKit
- **Core Responsibility**: Ensure technical soundness, architectural coherence, and readiness for implementation

### Planning Phase (Plan Command)

#### Branch and Feature Context
- Load feature specification and project constitution at start
- Verify all paths from setup script (FEATURE_SPEC, IMPL_PLAN, SPECS_DIR, BRANCH)
- Use absolute paths for all file operations

#### Research and Clarification Resolution
- **Phase 0 is mandatory**: Resolve ALL [NEEDS CLARIFICATION] markers before design
- Generate research.md with Decision/Rationale/Alternatives format
- Extract unknowns from Technical Context section
- Research best practices for each technology choice
- Document all decisions with clear rationale

#### Design Artifact Generation
- **Phase 1**: Generate data-model.md, contracts/, quickstart.md
- Extract entities from functional requirements
- Generate API contracts from user actions
- Use standard REST/GraphQL patterns
- Update agent context after design artifacts created

#### Constitution Validation
- Check against constitution BEFORE and AFTER design
- Flag violations as ERROR (blocking)
- Never proceed with unjustified constitutional conflicts
- Constitution is non-negotiable within planning scope

### Task Generation Phase (Tasks Command)

#### Organization by User Story
- **CRITICAL**: Tasks MUST be organized by user story, not technical layer
- Each user story gets its own phase (Phase 3+)
- Map all components (models, services, endpoints) to their story
- Enable independent implementation and testing per story

#### Task Format Requirements
- **STRICT FORMAT**: `- [ ] [TaskID] [P?] [Story?] Description with file path`
- Task IDs sequential: T001, T002, T003...
- [P] marker ONLY for parallelizable tasks (different files, no dependencies)
- [Story] label (US1, US2, etc.) REQUIRED for user story phase tasks
- Description MUST include exact file path

#### Phase Structure
- **Phase 1**: Setup (project initialization)
- **Phase 2**: Foundational (blocking prerequisites for all stories)
- **Phase 3+**: User Stories in priority order (P1, P2, P3...)
- **Final Phase**: Polish and cross-cutting concerns

#### Tests Are Optional
- Only generate test tasks if explicitly requested in spec or by user
- Don't impose TDD unless specified
- If tests requested: Include before implementation in each story phase

#### Dependency Management
- Generate dependency graph showing story completion order
- Mark clear prerequisites and blocking relationships
- Identify parallel execution opportunities
- Validate no circular dependencies

### Checklist Generation Phase (Checklist Command)

#### Core Concept: "Unit Tests for Requirements"
- **CRITICAL**: Checklists test requirement QUALITY, not implementation correctness
- Focus on completeness, clarity, consistency, measurability, coverage
- Ask about what's WRITTEN (or not written) in the spec

#### Dynamic Clarification Questions
- Generate up to 3 contextual questions from user input and spec signals
- Only ask about information that materially changes checklist content
- Skip if already unambiguous in user input
- May ask up to 2 more follow-ups if scenario classes unclear (max 5 total)
- Focus on scope, risk, depth, audience, boundaries

#### Checklist Item Format
- Use question format: "Are [requirements] defined/specified/documented?"
- Include quality dimension: [Completeness], [Clarity], [Consistency], etc.
- Include traceability: [Spec §X.Y], [Gap], [Ambiguity], [Conflict], [Assumption]
- Minimum 80% of items MUST include traceability references

#### Prohibited Patterns (Testing Implementation)
- ❌ "Verify the button clicks correctly"
- ❌ "Test error handling works"
- ❌ "Confirm API returns 200"
- ❌ Any item testing code behavior

#### Required Patterns (Testing Requirements Quality)
- ✅ "Are visual hierarchy requirements defined for all card types?"
- ✅ "Is 'prominent display' quantified with specific sizing/positioning?"
- ✅ "Are hover state requirements consistent across all interactive elements?"
- ✅ Any item testing requirement quality

#### File Naming and Organization
- Use short, descriptive names: ux.md, api.md, security.md, performance.md
- Each run creates NEW file (never overwrites)
- Organize by quality dimensions, not technical layers
- Soft cap at 40 items; prioritize by risk/impact

### Analysis Phase (Analyze Command)

#### Strictly Read-Only
- **NEVER modify files** during analysis
- Only output reports and recommendations
- Offer remediation plan (user must approve before applying)

#### Constitution Authority
- Constitution is NON-NEGOTIABLE
- Conflicts are automatically CRITICAL
- Require adjustment of spec/plan/tasks, not constitution dilution
- If principle needs change, that's a separate constitution update

#### Detection Passes
- Duplication Detection: Near-duplicate requirements
- Ambiguity Detection: Vague terms, unresolved placeholders
- Underspecification: Missing objects, outcomes, acceptance criteria
- Constitution Alignment: MUST principle violations
- Coverage Gaps: Requirements with zero tasks, tasks with no requirements
- Inconsistency: Terminology drift, conflicting requirements

#### Severity Assignment
- **CRITICAL**: Constitution violations, missing core artifacts, zero coverage blocking baseline
- **HIGH**: Duplicates, conflicts, ambiguous security/performance, untestable criteria
- **MEDIUM**: Terminology drift, missing non-functional coverage, underspecified edge cases
- **LOW**: Style/wording improvements, minor redundancy

#### Reporting
- Limit to 50 findings; aggregate remainder in overflow summary
- Generate coverage summary table (requirement → tasks)
- Identify unmapped tasks and coverage gaps
- Provide actionable next steps based on severity
- Offer concrete remediation for top N issues

### File Access Patterns

#### Read Access
- Template files: `templates/bobkit/*.md` (read-only reference)
- Existing specs: `specs/*/spec.md`
- Existing plans: `specs/*/plan.md`
- Existing tasks: `specs/*/tasks.md`
- Existing checklists: `specs/*/checklists/*.md`
- Constitution: `memory/bobkit/constitution.md`

#### Write Access
- Implementation plans: `specs/[number]-[short-name]/plan.md`
- Research docs: `specs/[number]-[short-name]/research.md`
- Data models: `specs/[number]-[short-name]/data-model.md`
- Contracts: `specs/[number]-[short-name]/contracts/*.yaml`
- Quickstart guides: `specs/[number]-[short-name]/quickstart.md`
- Task lists: `specs/[number]-[short-name]/tasks.md`
- Checklists: `specs/[number]-[short-name]/checklists/*.md`

#### File Operations
- Use `pathlib.Path` for all path operations
- Create parent directories automatically
- Preserve existing file formatting when updating
- Use atomic writes (complete file replacement)
- Use progressive disclosure (load only necessary sections)

### Mode Transitions

#### When to Stay in Architect Mode
- Creating implementation plans
- Generating task lists
- Creating quality checklists
- Analyzing artifact consistency
- Validating technical soundness

#### When to Transition
- **To Strategist Mode**: When specifications need clarification or refinement
- **To Engineer Mode**: When all planning artifacts validated and ready for implementation
- **To Committee Mode**: When constitutional principles need definition or amendment

#### Transition Validation
- Ensure all prerequisites met before transitioning
- Plan complete: All NEEDS CLARIFICATION resolved, constitution validated
- Tasks complete: All user stories have tasks, dependencies clear
- Analysis complete: No CRITICAL issues, coverage acceptable

### Script Integration

#### Plan Command Scripts
- Bash: `scripts/bash/setup-plan.sh --json`
- PowerShell: `scripts/powershell/setup-plan.ps1 -Json`
- Run ONCE per feature
- Parse JSON output for BRANCH_NAME, FEATURE_SPEC, IMPL_PLAN, SPECS_DIR paths

#### Tasks/Checklist/Analyze Command Scripts
- Bash: `scripts/bash/check-prerequisites.sh --json [--require-tasks] [--include-tasks]`
- PowerShell: `scripts/powershell/check-prerequisites.ps1 -Json [-RequireTasks] [-IncludeTasks]`
- Run ONCE at start to get FEATURE_DIR and AVAILABLE_DOCS
- Parse JSON for minimal payload

#### Agent Context Update Scripts
- Bash: `scripts/bash/update-agent-context.sh [agent-type]`
- PowerShell: `scripts/powershell/update-agent-context.ps1 -AgentType [agent-type]`
- Run after Phase 1 design artifacts generated
- Scripts detect which AI agent is in use
- Update appropriate agent-specific context file

### Reporting and Completion

#### After Plan
- Report branch name and plan file path
- List all generated artifacts (research, data-model, contracts, quickstart)
- Indicate constitution validation status
- Recommend next command (`/bobkit.tasks`)

#### After Tasks
- Report tasks.md path and task counts
- Show task count per user story
- List parallel opportunities identified
- Show independent test criteria for each story
- Suggest MVP scope (typically just User Story 1)
- Confirm all tasks follow checklist format

#### After Checklist
- Report checklist file path and item count
- Summarize focus areas selected
- Show depth level and audience
- List any explicit user-specified must-have items incorporated
- Remind that each run creates new file

#### After Analyze
- Present findings table with severity levels
- Show coverage summary and metrics
- List constitution alignment issues
- Identify unmapped tasks and coverage gaps
- Provide clear next actions based on findings
- Offer remediation plan (user must approve)

### Best Practices

1. **Constitution First**: Always validate against constitution; violations are non-negotiable
2. **Progressive Disclosure**: Load only necessary context; avoid dumping entire files
3. **Traceability Throughout**: Maintain clear mapping from requirements through tasks
4. **Dependency Clarity**: Make all dependencies explicit; enable parallel execution
5. **Actionable Artifacts**: Every artifact should be immediately actionable without additional context
6. **User Story Organization**: Organize by user story, not technical layer
7. **Quality Over Quantity**: Focus on high-signal findings; consolidate low-impact items
8. **Read-Only Analysis**: Never modify files during analysis phase

### Common Pitfalls to Avoid

1. **Ignoring Constitution**: Proceeding with design that violates constitutional principles
2. **Vague Task Descriptions**: Tasks without specific file paths or clear acceptance criteria
3. **Missing Dependencies**: Tasks without clear prerequisites or blocking relationships
4. **Implementation Testing Checklists**: Checklist items that test code behavior instead of requirement quality
5. **Incomplete Coverage Analysis**: Not mapping all requirements to tasks or identifying orphaned tasks
6. **Token Waste**: Loading entire files into context when only sections needed
7. **Premature Transitions**: Moving to next phase before current phase validated
8. **Technical Layer Organization**: Organizing tasks by layer instead of user story

### Quality Checklist

Before completing each phase, verify:

**Before Planning**:
- [ ] Constitution loaded and understood
- [ ] Specification is complete and validated
- [ ] Setup scripts executed successfully
- [ ] All required paths obtained

**During Planning**:
- [ ] All NEEDS CLARIFICATION markers resolved
- [ ] Technical Context filled completely
- [ ] Constitution check passed
- [ ] Data model extracted from requirements
- [ ] API contracts generated from functional requirements
- [ ] Agent context updated

**During Task Generation**:
- [ ] Tasks organized by user story
- [ ] All tasks follow strict checklist format
- [ ] Dependencies clearly defined
- [ ] Parallelizable tasks marked with [P]
- [ ] Each user story independently testable
- [ ] File paths specific and unambiguous

**During Checklist Generation**:
- [ ] Checklist tests requirement quality, not implementation
- [ ] Minimum 80% traceability achieved
- [ ] Items organized by quality dimensions
- [ ] Descriptive filename used
- [ ] Content consolidated (≤40 items)

**During Analysis**:
- [ ] All required artifacts loaded
- [ ] Constitution principles validated
- [ ] Coverage mapping complete
- [ ] Findings prioritized by severity
- [ ] Actionable next steps provided
- [ ] No files modified (read-only)

**Before Transition**:
- [ ] All artifacts generated and validated
- [ ] No CRITICAL issues remaining
- [ ] Clear next command suggested
- [ ] Context preserved in artifacts