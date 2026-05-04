---
description: "Perform a comprehensive code check of all implemented changes to ensure no conflicts, breaks, inconsistencies, or misalignments with the constitution and spec goals"
---
# Required
'switch_mode':
- slug: bobkit-stakeholder
- reason: Check command requires oversight and quality assurance authority to perform comprehensive validation of implementation outcomes

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

User input can include the flag `--create-findings-file` to generate a findings.md file at the root of the repository if issues are discovered during the review.

## Outline

1. Run `.specify/scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks` from repo root and parse FEATURE_DIR and AVAILABLE_DOCS list. All paths must be absolute. For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").

2. Load and analyze the check context:
   - **REQUIRED**: Read tasks.md for the complete task list and verify all tasks are marked as completed [X]
   - **REQUIRED**: Read plan.md for tech stack, architecture, and file structure to ensure implementation aligns
   - **REQUIRED**: Read constitution.md for core principles and guidelines to check compliance
   - **REQUIRED**: Read spec.md for original requirements and goals to verify alignment
   - **IF EXISTS**: Read data-model.md for entities and relationships to check consistency
   - **IF EXISTS**: Read contracts/ for API specifications and ensure they are met
   - **IF EXISTS**: Read research.md for technical decisions and constraints to validate adherence

3. Perform comprehensive code check of all changes:
   - **Git analysis**: Use git diff and git status to identify all modified, added, and deleted files
   - **Conflict detection**: Check for merge conflicts, uncommitted changes, or integration issues
   - **Break detection**: Review for potential runtime errors, import issues, or breaking changes
   - **Inconsistency identification**: Look for style violations, naming inconsistencies, or architectural mismatches
   - **Alignment verification**: Ensure all changes support the spec goals and follow constitution principles

4. Check execution rules:
   - **Holistic analysis**: Examine the entire implementation as a cohesive unit, not just individual files
   - **Cross-reference checking**: Verify that changes in one area don't negatively impact others
   - **Best practices validation**: Confirm adherence to coding standards, security practices, and performance guidelines
   - **Documentation review**: Check that code comments, README updates, and inline docs are accurate and complete
   - **Test coverage**: Verify that tests exist for new functionality and that existing tests still pass

5. Issue categorization and reporting:
   - **Critical issues**: Security vulnerabilities, breaking changes, or spec violations that must be fixed
   - **High priority**: Performance issues, major inconsistencies, or significant deviations from plan
   - **Medium priority**: Style issues, minor inconsistencies, or documentation gaps
   - **Low priority**: Nice-to-have improvements or minor optimizations
   - **Positive findings**: Well-implemented features, good practices, or innovative solutions

6. Progress tracking and recommendations:
    - Provide a detailed summary of the check findings
    - Suggest specific fixes for identified issues with file paths and line numbers where applicable
    - Recommend next steps, such as running tests, updating documentation, or making additional changes
    - **IMPORTANT**: If critical issues are found that prevent the feature from functioning, halt and require fixes before proceeding
    - **Issue resolution workflow**:
      - If critical or high-priority issues are identified, prompt the user: "Critical/high-priority issues detected that should be resolved before proceeding. Would you like me to: (A) Update tasks.md and run /bobkit.implement to fix them, or (B) Document them and proceed anyway?"
      - If medium or low-priority issues are found, prompt the user: "Medium/low-priority issues detected. Would you like me to: (A) Update tasks.md and run /bobkit.implement to fix them, (B) Document them in findings.md (if --create-findings-file was specified), or (C) Proceed as is?"
      - Wait for user response before taking any action
      - Only update tasks.md and run /bobkit.implement if user explicitly chooses option A
    - **Findings documentation**: If the user has included `--create-findings-file` in their arguments and issues are discovered, create a findings.md file at the root of the repository with the following structure:
      ```markdown
      # Code Review Findings
      
      ## Summary
      Brief overview of the review and key findings.
      
      ## Critical Issues
      
      ### [Issue Title]
      - **Location**: [File path:line number]
      - **Description**: Detailed explanation of the issue
      - **Impact**: How this affects the application/system
      - **Mitigation**: Suggested fix with code example if applicable
      
      ## High Priority Issues
      [Same format as Critical Issues]
      
      ## Medium Priority Issues
      [Same format as Critical Issues]
      
      ## Low Priority Issues
      [Same format as Critical Issues]
      
      ## Positive Findings
      - [Description of well-implemented features or good practices]
      ```

7. Completion validation:
   - Confirm that the implementation meets all spec requirements
   - Verify that the code follows the technical plan and architecture decisions
   - Ensure compliance with constitution principles and development guidelines
   - Validate that no new technical debt has been introduced
   - Report final status with a clear pass/fail assessment and actionable feedback
   - **Pull Request creation**: After validation is complete and if no blocking issues remain:
     - Check if the current environment supports PR creation (GitHub CLI available with `gh pr create` command)
     - If PR creation is supported, ask the user: "Code review complete. Would you like to create a Pull Request? (yes/no)"
     - If user responds "yes", use the `create_pull_request` tool (if available) or provide instructions for manual PR creation
     - If user responds "no" or PR creation is not supported, provide a summary and suggest next steps
   - **Final reminder**: "✅ Code review complete. This is the final step in the BobKit workflow. If issues were found, **start a new task** to address them with `/bobkit.implement`. Otherwise, your feature is ready for merge!"

Note: This command assumes implementation is complete via /bobkit.implement. If tasks are incomplete or issues are found, suggest running /bobkit.tasks to update the task list or /bobkit.implement to make corrections.
