---
name: update-from-template
description: Pull this branch's upstream template updates without auto-committing, resolve conflicts in favor of project intent, and verify before completing the merge.
---

# Update from the template

Require a clean working tree. Confirm `upstream` points to the template repository; do not replace
an existing remote without approval.

```bash
git remote -v
git fetch upstream backend-only
git log --oneline HEAD..upstream/backend-only
git pull --no-rebase --no-commit upstream backend-only
```

Review incoming commits before pulling. The pull intentionally leaves the merge uncommitted.

Resolve conflicts by preserving project behavior while applying the upstream fix:

- Resolve `package.json` first, then regenerate `pnpm-lock.yaml` with `pnpm install`; do not
  hand-merge the lockfile.
- Preserve API-key authentication, the absence of users/ownership/frontend, environment names,
  deployment topology, and application changes. Never reintroduce files deliberately removed.
- Preserve applied Alembic history. If upstream changes its earlier revisions, keep the project's
  history and create a new forward revision for any required schema change.
- Do not reintroduce generated-client or route-tree files; this branch has no frontend.

Run `pnpm install`, `uv sync --project backend`, `pnpm run verify`, and
`pnpm run test:deploy`. Inspect the staged merge, then finish with `git merge --continue`. Abort an
unwanted merge with `git merge --abort`.
