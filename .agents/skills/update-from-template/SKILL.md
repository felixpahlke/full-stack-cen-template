---
name: update-from-template
description: Pull this branch's upstream template updates without auto-committing, resolve conflicts in favor of project intent, and verify before completing the merge.
---

# Update from the template

Require a clean working tree. Confirm `upstream` points to the template repository; do not replace
an existing remote without approval.

```bash
git remote -v
git fetch upstream local-auth
git log --oneline HEAD..upstream/local-auth
git pull --no-rebase --no-commit upstream local-auth
```

Review incoming commits before pulling. The pull intentionally leaves the merge uncommitted.

Resolve conflicts by preserving project behavior while applying the upstream fix:

- Resolve `package.json` first, then regenerate `package-lock.json` with `npm install`; do not
  hand-merge the lockfile.
- Preserve this project's authentication, Carbon UI, environment names, deployment topology, and
  application changes. Never reintroduce files the project deliberately removed.
- Preserve applied Alembic history. If upstream changes its earlier revisions, keep the project's
  history and create a new forward revision for any required schema change.
- Never hand-edit generated client or route-tree files. Resolve backend source first, then run
  `npm run generate-client`.

Run `npm ci`, `npm ci --prefix frontend`, `uv sync --project backend`, `npm run verify`, and
`npm run test:deploy`. Inspect the staged merge, then finish with `git merge --continue`. Abort an
unwanted merge with `git merge --abort`.
