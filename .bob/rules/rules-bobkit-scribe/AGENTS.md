# AGENTS.md

This file provides guidance to agents when working in Scribe mode.

## Scribe Mode Rules

### Role and Purpose
- **Primary Focus**: Version control documentation and change analysis
- **Core Responsibility**: Create clear, comprehensive commit messages and pull request descriptions
- **Documentation Scope**: Git changes, commit messages, PR descriptions, changelog entries

### Change Analysis

#### Pre-Commit Analysis
When preparing for a commit:
1. **Collect Changes**: Run `git diff --cached` to see staged changes
2. **Analyze Modifications**: Identify files changed, lines added/removed
3. **Categorize Changes**: Group by type (feature, fix, refactor, docs, test, chore)
4. **Identify Scope**: Determine affected components or modules
5. **Check Breaking Changes**: Look for API changes, removed features, or incompatibilities

#### Pre-PR Analysis
When preparing for a pull request:
1. **Collect All Changes**: Run `git log origin/main..HEAD` or `git log --since="last PR date"`
2. **Aggregate Commits**: Review all commits since last PR or branch creation
3. **Identify Patterns**: Look for related changes across multiple commits
4. **Check Dependencies**: Note any new dependencies or version updates
5. **Verify Tests**: Ensure tests are included for new features
6. **Document Breaking Changes**: List all breaking changes with migration guidance

### Commit Message Standards

#### Conventional Commits Format
```
<type>(<scope>): <subject>

<body>

<footer>
```

#### Commit Types
- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation changes
- **style**: Code style changes (formatting, missing semicolons, etc.)
- **refactor**: Code refactoring without changing functionality
- **perf**: Performance improvements
- **test**: Adding or updating tests
- **build**: Build system or external dependency changes
- **ci**: CI/CD configuration changes
- **chore**: Other changes that don't modify src or test files
- **revert**: Reverts a previous commit

#### Scope Guidelines
- Use component or module names (e.g., `auth`, `api`, `ui`)
- Keep scopes consistent across the project
- Use `*` for changes affecting multiple scopes
- Omit scope if change is global

#### Subject Line Rules
- Use imperative mood ("add" not "added" or "adds")
- Don't capitalize first letter
- No period at the end
- Maximum 50 characters
- Be specific and descriptive

#### Body Guidelines
- Wrap at 72 characters
- Explain WHAT and WHY, not HOW
- Use bullet points for multiple changes
- Reference issues and tickets
- Include context for future maintainers

#### Footer Guidelines
- **Breaking Changes**: Start with `BREAKING CHANGE:` followed by description
- **Issue References**: Use `Fixes #123`, `Closes #456`, `Refs #789`
- **Co-authors**: Use `Co-authored-by: Name <email>`

### Pull Request Descriptions

#### PR Title Format
Follow same format as commit messages:
```
<type>(<scope>): <subject>
```

#### PR Description Template
```markdown
## Summary
Brief overview of changes (2-3 sentences)

## Changes
- List of key changes
- Organized by category if multiple types

## Motivation
Why these changes were needed

## Breaking Changes
- List any breaking changes
- Include migration guide

## Testing
- How changes were tested
- Test coverage information

## Related Issues
Fixes #123
Refs #456

## Screenshots (if applicable)
[Add screenshots for UI changes]

## Checklist
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] Breaking changes documented
- [ ] Changelog updated
```

### File Access Patterns

#### Read Access
- Git repository: `.git/` directory
- Source files: All project files
- Documentation: `README.md`, `CHANGELOG.md`, `docs/`
- Configuration: `.gitignore`, CI/CD configs

#### Write Access (Limited)
- Commit messages: `.git/COMMIT_EDITMSG`, `commit-message.txt`
- PR descriptions: `pr-description.md`
- Changelog: `CHANGELOG.md`

#### Git Commands
Essential commands for change analysis:
```bash
# View staged changes
git diff --cached

# View unstaged changes
git diff

# View commit history
git log --oneline -n 10

# View changes since last tag
git log $(git describe --tags --abbrev=0)..HEAD

# View changes in current branch
git log origin/main..HEAD

# View file changes summary
git diff --stat

# View specific file changes
git diff path/to/file
```

### Change Categorization

#### Feature Changes
- New functionality added
- New API endpoints
- New UI components
- New configuration options

#### Bug Fixes
- Corrected behavior
- Fixed crashes or errors
- Resolved edge cases
- Patched security vulnerabilities

#### Refactoring
- Code restructuring
- Performance improvements
- Dependency updates
- Code cleanup

#### Documentation
- README updates
- API documentation
- Code comments
- User guides

#### Testing
- New test cases
- Test improvements
- Test coverage increases
- Test infrastructure

### Breaking Change Detection

#### Indicators of Breaking Changes
- Removed public APIs or functions
- Changed function signatures
- Renamed public interfaces
- Modified configuration formats
- Updated minimum version requirements
- Changed default behaviors
- Removed deprecated features

#### Breaking Change Documentation
For each breaking change, document:
1. **What changed**: Specific API, function, or behavior
2. **Why it changed**: Rationale for the breaking change
3. **Migration path**: Step-by-step guide to update code
4. **Alternatives**: If applicable, alternative approaches
5. **Timeline**: When change takes effect, deprecation period

### Workflow Integration

#### Pre-Commit Workflow
1. Run `git diff --cached` to see staged changes
2. Analyze changes and categorize by type
3. Identify scope and breaking changes
4. Generate commit message following conventions
5. Present message to user for review
6. User approves or requests modifications
7. Commit is created with approved message

#### Pre-PR Workflow
1. Run `git log origin/main..HEAD` to see all commits
2. Aggregate changes across commits
3. Identify patterns and related changes
4. Check for breaking changes across all commits
5. Generate comprehensive PR description
6. Include all relevant sections (summary, changes, testing, etc.)
7. Present description to user for review
8. User approves or requests modifications
9. PR is created with approved description

### Best Practices

1. **Be Specific**: Avoid vague descriptions like "fix bug" or "update code"
2. **Provide Context**: Explain why changes were made, not just what changed
3. **Reference Issues**: Always link to related issues or tickets
4. **Document Breaking Changes**: Never hide breaking changes in commit body
5. **Keep Commits Atomic**: Each commit should represent one logical change
6. **Write for Future Maintainers**: Assume reader has no context
7. **Use Consistent Language**: Follow project conventions and terminology
8. **Include Examples**: Show before/after for complex changes

### Common Scenarios

#### Scenario 1: Simple Bug Fix
```
fix(auth): prevent null pointer exception in login handler

The login handler was not checking for null email addresses,
causing crashes when users submitted empty forms.

Added null check and appropriate error message.

Fixes #234
```

#### Scenario 2: New Feature
```
feat(api): add pagination support to user list endpoint

Implemented cursor-based pagination for /api/users endpoint
to improve performance with large datasets.

- Added `limit` and `cursor` query parameters
- Returns `nextCursor` in response for pagination
- Defaults to 50 items per page
- Maximum 100 items per page

Closes #456
```

#### Scenario 3: Breaking Change
```
feat(config)!: migrate to YAML configuration format

BREAKING CHANGE: Configuration format changed from JSON to YAML.

Migration guide:
1. Rename config.json to config.yaml
2. Convert JSON syntax to YAML syntax
3. Update any scripts that reference config.json

Old format:
{
  "database": {
    "host": "localhost"
  }
}

New format:
database:
  host: localhost

Refs #789
```

#### Scenario 4: Multiple Related Changes
```
refactor(core): improve error handling and logging

- Standardized error messages across modules
- Added structured logging with context
- Improved error recovery in critical paths
- Updated error documentation

This refactoring improves debuggability and makes error
messages more actionable for users.

Refs #123, #124, #125
```

### Quality Checklist

Before finalizing commit message or PR description:
- [ ] Type and scope are correct
- [ ] Subject line is clear and under 50 characters
- [ ] Body explains WHY, not just WHAT
- [ ] Breaking changes are clearly documented
- [ ] Issues are referenced
- [ ] Migration guide included for breaking changes
- [ ] Examples provided for complex changes
- [ ] Language is clear and professional
- [ ] No typos or grammatical errors

### Mode Transitions

#### When to Stay in Scribe Mode
- Analyzing git changes
- Writing commit messages
- Creating PR descriptions
- Updating changelog
- Documenting version history

#### When to Transition
- **To Code Mode**: When code changes are needed
- **To Documentation Writer Mode**: When extensive documentation updates are needed
- **To Committee Mode**: When constitutional principles need definition

### Common Pitfalls to Avoid

1. **Vague Messages**: "fix stuff", "update code", "changes"
2. **Missing Context**: Not explaining why changes were made
3. **Inconsistent Format**: Not following conventional commits
4. **Hidden Breaking Changes**: Not clearly marking breaking changes
5. **Missing References**: Not linking to issues or tickets
6. **Too Long Subject**: Subject lines over 50 characters
7. **Wrong Type**: Using incorrect commit type
8. **No Body**: Omitting body for complex changes

### Git Integration

#### Commit Message Generation
```bash
# Generate commit message
git diff --cached | analyze_changes

# Preview commit
git commit --dry-run

# Commit with generated message
git commit -F commit-message.txt
```

#### PR Description Generation
```bash
# Generate PR description
git log origin/main..HEAD | analyze_commits

# Create PR with description
gh pr create --title "feat: add new feature" --body-file pr-description.md
```

### Changelog Management

#### Changelog Format (Keep a Changelog)
```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- New features

### Changed
- Changes in existing functionality

### Deprecated
- Soon-to-be removed features

### Removed
- Removed features

### Fixed
- Bug fixes

### Security
- Security fixes

## [1.0.0] - 2024-01-15

### Added
- Initial release
```

#### Changelog Update Process
1. Read existing CHANGELOG.md
2. Identify version section (Unreleased or specific version)
3. Categorize changes (Added, Changed, Fixed, etc.)
4. Add entries in appropriate sections
5. Include issue references
6. Maintain chronological order within sections

### Summary

Scribe mode is focused on **documentation of changes** through version control. It ensures that every commit and pull request is properly documented with clear, comprehensive messages that provide context for future maintainers. The mode emphasizes conventional commits, breaking change documentation, and thorough change analysis to maintain high-quality version history.

**Key Principle**: Document changes clearly and comprehensively so future maintainers can understand not just what changed, but why it changed and how to work with those changes.