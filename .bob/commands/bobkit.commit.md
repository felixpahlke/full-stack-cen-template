---
description: Review current code changes and commit them with a comprehensive summary to the current branch
---
# Required
'switch_mode':
- slug: bobkit-scribe
- reason: Need to analyze git changes, generate conventional commit message, and document changes for version control

# User Input
User input:

$ARGUMENTS

The user input to you can be provided directly by the agent or as a command argument - you **MUST** consider it before proceeding with the prompt (if not empty).

User input:

$ARGUMENTS

# Code Review and Commit Process

**CRITICAL INSTRUCTION: This command will review, commit, and push code changes. Always confirm the changes with the user before committing.**

## 1. Identify Current Branch

First, determine the current branch name:

```bash
git branch --show-current
```

Store this branch name for use in commit and push operations.

## 2. Review Staged and Unstaged Changes

Check the current status of the repository:

```bash
git status
```

Get a detailed diff of all changes (staged and unstaged):

```bash
git diff HEAD
```

If there are unstaged changes, also show:

```bash
git diff
```

## 3. Analyze Changes

Review the diff output and analyze:

- **Files modified**: List all files that have been changed
- **Nature of changes**: Categorize changes by type:
  - New features added
  - Bug fixes
  - Refactoring
  - Documentation updates
  - Configuration changes
  - Dependency updates
  - Breaking changes
- **Impact assessment**: Identify which components/modules are affected
- **Related files**: Check if changes span multiple related files

## 4. Generate Comprehensive Commit Message

Create a detailed commit message following this structure:

```
<type>(<scope>): <short summary>

<detailed description>

- Change 1: Description of what changed and why
- Change 2: Description of what changed and why
- Change 3: Description of what changed and why

[Optional sections:]
Breaking Changes: <if applicable>
Related Issues: <if applicable>
Co-authored-by: <if applicable>
```

**Commit message types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Test additions or modifications
- `build`: Build system or dependency changes
- `ci`: CI/CD configuration changes
- `chore`: Other changes that don't modify src or test files

**Scope examples:** `cli`, `api`, `ui`, `docs`, `config`, `deps`, `release`

## 5. Present Summary to User

Before committing, present a clear summary:

```
📋 COMMIT SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Current Branch: <branch-name>

Files Changed:
  - path/to/file1.ext (additions: X, deletions: Y)
  - path/to/file2.ext (additions: X, deletions: Y)

Proposed Commit Message:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
<full commit message>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Would you like to proceed with this commit? (yes/no)
```

**Wait for user confirmation before proceeding.**

## 6. Stage All Changes

If user confirms, stage all changes:

```bash
git add -A
```

Verify staged changes:

```bash
git status
```

## 7. Create Commit

Commit the changes with the generated message:

```bash
git commit -m "<commit message>"
```

For multi-line commit messages, use:

```bash
git commit -F - <<'EOF'
<multi-line commit message>
EOF
```

## 8. Push to Current Branch

Push the commit to the remote repository on the current branch:

```bash
git push origin <current-branch-name>
```

If this is the first push to a new branch:

```bash
git push -u origin <current-branch-name>
```

## 9. Verification

After pushing, verify the commit:

```bash
git log -1 --stat
```

Confirm the remote branch is up to date:

```bash
git status
```

## 10. Report Completion

Provide a final summary to the user:

```
✅ COMMIT COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Branch: <branch-name>
Commit: <commit-hash>
Files Changed: <count>
Remote: Successfully pushed to origin/<branch-name>

Summary: <brief description of what was committed>
```

## Error Handling

### Merge Conflicts
If there are merge conflicts:
1. Show the conflicting files
2. Explain the conflict
3. Ask user to resolve conflicts manually
4. Suggest: `git status` to check conflicts, then re-run this command

### Push Rejected
If push is rejected (e.g., remote has changes):
1. Suggest pulling first: `git pull origin <branch-name>`
2. Resolve any conflicts
3. Re-run this command

### No Changes to Commit
If there are no changes:
1. Report: "No changes detected in the working directory"
2. Show current branch status
3. Exit gracefully

## Best Practices

1. **Atomic commits**: Each commit should represent a single logical change
2. **Clear messages**: Commit messages should explain both what and why
3. **Review before commit**: Always review the diff before committing
4. **Test before push**: Ensure code works before pushing
5. **Branch awareness**: Always verify you're on the correct branch
6. **Meaningful scope**: Use appropriate scope in commit messages
7. **Breaking changes**: Clearly mark breaking changes in commit message

## Notes

- This command works with the current branch only
- All changes (staged and unstaged) will be included in the commit
- The commit message follows conventional commit format
- Push operations target the remote named 'origin'
- User confirmation is required before committing and pushing
