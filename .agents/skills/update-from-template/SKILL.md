---
name: update-from-template
description: Pull this branch's upstream template updates without auto-committing, resolve conflicts in favor of project intent, and verify before completing the merge.
---

# Update from the template

Require a clean working tree. Confirm `upstream` points to the template repository; do not replace
an existing remote without approval.

```bash
git remote -v
git fetch upstream local-auth-custom-ui
git log --oneline HEAD..upstream/local-auth-custom-ui
git pull --no-rebase --no-commit upstream local-auth-custom-ui
```

Review incoming commits before pulling. The pull intentionally leaves the merge uncommitted.

Resolve conflicts by preserving project behavior while applying the upstream fix:

- Resolve workspace package manifests first, then regenerate `pnpm-lock.yaml` with `pnpm install`;
  do not hand-merge the lockfile.
- Preserve this project's authentication, shadcn UI, environment names, deployment topology, and
  application changes. Never reintroduce files the project deliberately removed.
- Preserve applied Alembic history. If upstream changes its earlier revisions, keep the project's
  history and create a new forward revision for any required schema change.
- Never hand-edit generated client or route-tree files. Resolve backend source first, then run
  `pnpm run generate-client`.

Run `pnpm install`, `uv sync --project backend`, `pnpm run verify`, and
`pnpm run test:deploy`. Inspect the staged merge, then finish with `git merge --continue`. Abort an
unwanted merge with `git merge --abort`.
