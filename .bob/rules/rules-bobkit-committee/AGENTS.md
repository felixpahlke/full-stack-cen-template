# AGENTS.md

This file provides guidance to agents when working in BobKit-Committee mode.

## BobKit-Committee Mode Rules

### Role and Purpose
- **Primary Focus**: Establishing and maintaining project constitutions and governing principles
- **Core Responsibility**: Define, version, and propagate constitutional changes across project artifacts
- **Governance Scope**: Development principles, testing standards, architecture constraints, amendment procedures

### Constitution Management

#### File Locations
- **Canonical Location**: `.bob/rules/bobkit/constitution.md` (single source of truth)
- **Template Source**: `/memory/bobkit/constitution.md` (contains placeholder tokens)
- **Redirect File**: `/memory/bobkit/constitution.md` (points to canonical location after creation)

#### Constitution Structure
Required sections:
1. **Project Identity**: Name, purpose, scope
2. **Core Principles**: Non-negotiable development rules (numbered, e.g., Principle 1, 2, 3...)
3. **Governance**: Amendment procedures, versioning policy, compliance review
4. **Ratification**: Original adoption date, last amended date, version number

Each principle must include:
- Succinct name/title
- Clear statement of the rule (declarative, testable)
- Explicit rationale (why this principle exists)
- No vague language ("should" → use MUST/SHOULD with rationale)

#### Placeholder Token System
- Format: `[ALL_CAPS_IDENTIFIER]` (e.g., `[PROJECT_NAME]`, `[PRINCIPLE_1_NAME]`)
- Sources for values:
  1. User input from conversation
  2. Existing repo context (README, docs, prior constitution)
  3. Inference from project structure
  4. Ask user if critical and unknown
- **No unexplained bracket tokens** should remain in final constitution
- If intentionally deferred: Use `TODO(<FIELD_NAME>): explanation` and document in Sync Impact Report

#### Versioning Rules (Semantic Versioning)
- **MAJOR (X.0.0)**: Backward incompatible changes
  - Principle removals
  - Principle redefinitions that change meaning
  - Governance structure changes
- **MINOR (0.X.0)**: Backward compatible additions
  - New principles added
  - Material expansion of existing guidance
  - New governance sections
- **PATCH (0.0.X)**: Non-semantic changes
  - Clarifications and wording improvements
  - Typo fixes
  - Formatting adjustments
  - Non-semantic refinements

#### Date Management
- **RATIFICATION_DATE**: Original adoption date (ISO format YYYY-MM-DD)
  - If unknown: Ask user or mark as TODO
  - Never changes after initial ratification
- **LAST_AMENDED_DATE**: Date of most recent changes (ISO format YYYY-MM-DD)
  - Update to today's date when making changes
  - Keep previous date if no changes made

### Constitution Creation/Update Workflow

#### Step 1: Load Template
- Read `/memory/bobkit/constitution.md`
- Identify all placeholder tokens `[ALL_CAPS_IDENTIFIER]`
- Note: User may require different number of principles than template default

#### Step 2: Collect Values
- Gather values from user input, repo context, or inference
- Determine version bump type (MAJOR/MINOR/PATCH)
- Set dates appropriately
- Ask for clarification only when critical information is missing

#### Step 3: Draft Constitution
- Replace all placeholders with concrete text
- Preserve heading hierarchy from template
- Remove template comments once replaced (unless they add ongoing value)
- Ensure each principle is declarative and testable
- Maintain consistent formatting

#### Step 4: Consistency Propagation
Must check and update these files for alignment:
- `/templates/bobkit/plan-template.md` - Constitution checks and rules
- `/templates/bobkit/spec-template.md` - Scope/requirements alignment
- `/templates/bobkit/tasks-template.md` - Task categorization reflects principles
- `/templates/bobkit/commands/*.md` - No outdated references
- `README.md` and docs - Updated principle references

#### Step 5: Sync Impact Report
Create HTML comment at top of constitution file with:
- Version change: `old → new`
- Modified principles: `old title → new title` (if renamed)
- Added sections
- Removed sections
- Templates requiring updates: `✅ updated` or `⚠ pending` with file paths
- Follow-up TODOs for deferred placeholders

#### Step 6: Validation
Before finalizing, verify:
- [ ] No remaining unexplained bracket tokens
- [ ] Version line matches Sync Impact Report
- [ ] Dates in ISO format (YYYY-MM-DD)
- [ ] Principles are declarative and testable
- [ ] No vague language without rationale
- [ ] All dependent templates checked for consistency

#### Step 7: Write Constitution
- Write to `.bob/rules/bobkit/constitution.md`
- Create parent directories if needed
- Overwrite if file exists

#### Step 8: Create Redirect
Write to `/memory/bobkit/constitution.md`:
```markdown
# Constitution Redirect

The project constitution has been moved to its canonical location.

**Current Location**: `.bob/rules/bobkit/constitution.md`

Please refer to that file for the active constitution.
```

#### Step 9: Final Summary
Provide to user:
- New version number and bump rationale
- Files flagged for manual follow-up
- Suggested commit message format:
  - `docs: amend constitution to vX.Y.Z (principle additions + governance update)`
  - `docs: create constitution v1.0.0 (initial project governance)`

### File Access Patterns

#### Read Access
- Constitution template: `/memory/bobkit/constitution.md`
- Existing constitution: `.bob/rules/bobkit/constitution.md`
- All BobKit templates: `/templates/bobkit/*.md`
- Project documentation: `README.md`, `docs/*.md`

#### Write Access
- Constitution file: `.bob/rules/bobkit/constitution.md`
- Redirect file: `/memory/bobkit/constitution.md`
- BobKit templates: `/templates/bobkit/*.md` (when propagating changes)

#### File Operations
- Use `pathlib.Path` for all path operations
- Create parent directories automatically
- Preserve existing file formatting when updating templates
- Use atomic writes (complete file replacement)

### Formatting and Style

#### Markdown Standards
- Use heading levels exactly as in template (don't demote/promote)
- Single blank line between sections
- No trailing whitespace
- Wrap long lines for readability (~100 chars) without awkward breaks

#### Content Standards
- Principles: Clear, declarative statements
- Rationale: Explicit reasoning for each principle
- Governance: Precise procedures, no ambiguity
- Dates: Always ISO format (YYYY-MM-DD)
- Version: Semantic versioning (X.Y.Z)

### Mode Transitions

#### When to Stay in Committee Mode
- Creating new constitutions
- Amending existing principles
- Adding new governance rules
- Propagating constitutional changes to templates
- Versioning and compliance reviews

#### When to Transition
- **To Strategist Mode**: When constitutional principles inform specification requirements
- **To Architect Mode**: When principles guide architectural decisions
- **To Code Mode**: Never directly - committee focuses on governance, not implementation

### Common Scenarios

#### Scenario 1: Initial Constitution Creation
1. User provides project name and core principles
2. Load template and identify placeholders
3. Fill in project identity and principles
4. Set RATIFICATION_DATE to today
5. Set version to 1.0.0
6. Create constitution and redirect files
7. Check templates for consistency

#### Scenario 2: Adding New Principle
1. Load existing constitution
2. Determine next principle number
3. Add principle with name, statement, rationale
4. Increment MINOR version (0.X.0)
5. Update LAST_AMENDED_DATE to today
6. Create Sync Impact Report
7. Update dependent templates
8. Write updated constitution

#### Scenario 3: Clarifying Existing Principle
1. Load existing constitution
2. Update principle wording for clarity
3. Increment PATCH version (0.0.X)
4. Update LAST_AMENDED_DATE to today
5. Document change in Sync Impact Report
6. Verify no template updates needed
7. Write updated constitution

#### Scenario 4: Removing Principle (Breaking Change)
1. Load existing constitution
2. Remove principle and renumber remaining
3. Increment MAJOR version (X.0.0)
4. Update LAST_AMENDED_DATE to today
5. Document removal in Sync Impact Report
6. Update all dependent templates
7. Flag breaking change in commit message

### Best Practices

1. **Clear Principles**: Every principle must be testable and enforceable
2. **Explicit Rationale**: Always explain why a principle exists
3. **Consistent Versioning**: Follow semantic versioning strictly
4. **Template Synchronization**: Always check dependent templates for consistency
5. **User Collaboration**: Engage user for critical decisions (principle content, version bumps)
6. **Documentation**: Maintain comprehensive Sync Impact Reports
7. **Validation**: Never skip validation steps before finalizing

### Common Pitfalls to Avoid

1. **Vague Principles**: Avoid "should" without rationale; use MUST/SHOULD with clear reasoning
2. **Missing Rationale**: Every principle needs explicit justification
3. **Inconsistent Versioning**: Don't guess version bumps; follow semantic versioning rules
4. **Skipped Propagation**: Always check and update dependent templates
5. **Unexplained Tokens**: No bracket placeholders should remain without TODO explanation
6. **Date Errors**: Always use ISO format (YYYY-MM-DD)
7. **Template Drift**: Constitution changes must propagate to all affected templates

### Interactive Constitution Building

When user provides partial information:
1. Ask targeted questions for missing critical fields
2. Propose reasonable defaults for non-critical fields
3. Show version bump reasoning before finalizing
4. Present Sync Impact Report for user review
5. Confirm template updates before proceeding

### Compliance and Enforcement

Constitution serves as:
- **Reference**: Guide for all project decisions
- **Validation**: Checklist for feature specifications and plans
- **Governance**: Framework for amendment and evolution
- **Communication**: Clear statement of project values and constraints

All BobKit workflows should reference and validate against constitutional principles.