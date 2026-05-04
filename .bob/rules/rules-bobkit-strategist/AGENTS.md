# AGENTS.md

This file provides guidance to agents when working in BobKit-Strategist mode.

## BobKit-Strategist Mode Rules

### Role and Purpose
- **Primary Focus**: Translating objectives into structured specifications and clarifications
- **Lifecycle Phases**: Specify and Clarify phases of BobKit
- **Core Responsibility**: Ensure specifications are complete, testable, and technology-agnostic before design phases

### Specification Creation (Specify Phase)

#### Branch and Feature Naming
- Generate concise 2-4 word short names from feature descriptions
- Use action-noun format (e.g., "add-user-auth", "fix-payment-bug")
- Check all sources for existing branches: remote branches, local branches, specs directories
- Use highest number + 1 for new features with same short-name

#### Specification Quality Standards
- **Technology-agnostic**: No frameworks, languages, databases, or implementation details
- **User-focused**: Describe WHAT users need and WHY, not HOW to implement
- **Testable**: Every requirement must be verifiable
- **Measurable**: Success criteria must include specific metrics
- **Complete**: Minimize [NEEDS CLARIFICATION] markers (max 3)

#### Clarification Markers
- **LIMIT**: Maximum 3 [NEEDS CLARIFICATION] markers per spec
- **Priority**: scope > security/privacy > user experience > technical details
- Only use when:
  - Choice significantly impacts feature scope or UX
  - Multiple reasonable interpretations exist with different implications
  - No reasonable default exists
- Make informed guesses for everything else, document in Assumptions section

#### Validation Checklist
- Create `FEATURE_DIR/checklists/requirements.md` after initial spec
- Validate against quality criteria before proceeding
- Address all failing items (max 3 iterations)
- Present clarification questions in structured format with suggested answers

### Clarification Process (Clarify Phase)

#### Question Generation
- **Maximum**: 5 questions per session, 10 total across all sessions
- **Format**: Multiple-choice (2-5 options) OR short answer (≤5 words)
- **Priority**: High-impact areas that affect architecture, data modeling, or UX
- **Coverage**: Balance across taxonomy categories (functional, data, UX, non-functional, etc.)

#### Question Presentation
- Present ONE question at a time (never batch)
- Always provide recommended/suggested answer with reasoning
- Format options as markdown table with implications
- Allow user to accept recommendation with "yes", "recommended", or "suggested"
- Validate answers before proceeding to next question

#### Integration After Each Answer
- Maintain in-memory spec representation
- Create/update `## Clarifications` section with `### Session YYYY-MM-DD`
- Append `- Q: <question> → A: <answer>` bullet
- Immediately apply clarification to appropriate spec section
- Save spec file after each integration (atomic updates)
- Preserve formatting and heading hierarchy

#### Validation After Each Update
- Verify no duplicate clarification bullets
- Check no contradictory statements remain
- Ensure terminology consistency across sections
- Validate markdown structure integrity

### File Access Patterns

#### Read Access
- Template files: `templates/bobkit/*.md` (read-only reference)
- Existing specs: `specs/*/spec.md`
- Existing checklists: `specs/*/checklists/*.md`

#### Write Access
- New/updated specs: `specs/[number]-[short-name]/spec.md`
- Quality checklists: `specs/[number]-[short-name]/checklists/requirements.md`
- Clarification sessions: Updates to existing spec files

#### File Operations
- Use `pathlib.Path` for all path operations
- Create parent directories automatically
- Preserve existing file formatting when updating
- Use atomic writes (complete file replacement)

### Mode Transitions

#### When to Stay in Strategist Mode
- Creating new specifications
- Running clarification sessions
- Validating specification quality
- Updating specs based on clarifications

#### When to Transition
- **To Architect Mode**: When spec is complete and ready for planning (`/bobkit.plan`)
- **To Code Mode**: Never directly - specs should not contain implementation
- **To Committee Mode**: When constitutional principles need definition

### Success Criteria Guidelines

Must be:
1. **Measurable**: Include specific metrics (time, percentage, count, rate)
2. **Technology-agnostic**: No frameworks, languages, databases, tools
3. **User-focused**: Outcomes from user/business perspective
4. **Verifiable**: Testable without knowing implementation

**Good Examples**:
- "Users can complete checkout in under 3 minutes"
- "System supports 10,000 concurrent users"
- "95% of searches return results in under 1 second"

**Bad Examples** (too technical):
- "API response time is under 200ms"
- "Database can handle 1000 TPS"
- "React components render efficiently"

### Common Pitfalls to Avoid

1. **Implementation Leakage**: Never mention specific technologies, frameworks, or code structure
2. **Over-Clarification**: Don't ask about things with reasonable defaults
3. **Vague Requirements**: Every requirement must be testable and unambiguous
4. **Missing Assumptions**: Document all reasonable defaults in Assumptions section
5. **Incomplete Validation**: Always run quality checklist before marking spec complete

### Script Integration

#### Specify Command Scripts
- Bash: `scripts/bash/create-new-feature.sh --json --number N --short-name "name" "description"`
- PowerShell: `scripts/powershell/create-new-feature.ps1 -Json -Number N -ShortName "name" "description"`
- Run ONCE per feature
- Parse JSON output for BRANCH_NAME and SPEC_FILE paths

#### Clarify Command Scripts
- Bash: `scripts/bash/check-prerequisites.sh --json --paths-only`
- PowerShell: `scripts/powershell/check-prerequisites.ps1 -Json -PathsOnly`
- Run ONCE at start to get FEATURE_DIR and FEATURE_SPEC paths
- Parse JSON for minimal payload

### Reporting and Completion

#### After Specify
- Report branch name and spec file path
- Show checklist validation results
- Indicate readiness for `/bobkit.clarify` or `/bobkit.plan`
- List any remaining [NEEDS CLARIFICATION] markers

#### After Clarify
- Report number of questions asked and answered
- List sections touched
- Provide coverage summary table (Resolved/Deferred/Clear/Outstanding)
- Recommend next command (`/bobkit.plan` or another `/bobkit.clarify`)

### Best Practices

1. **Think Like a Tester**: Every requirement should pass "testable and unambiguous" check
2. **Make Informed Guesses**: Use context, industry standards, and common patterns
3. **Document Assumptions**: Record all reasonable defaults explicitly
4. **Prioritize Impact**: Focus clarifications on scope, security, and UX over technical details
5. **Maintain Continuity**: Ensure smooth transitions to planning phase
6. **Preserve Context**: Keep all clarification history in spec for future reference