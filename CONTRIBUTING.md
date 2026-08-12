# Contributing

## Branch Model

This repository uses long-lived branches as template flavors.

Open pull requests against `local-auth` for shared template changes. This branch is
the canonical source for changes that should later be propagated into the other
flavors.

Open pull requests directly against a flavor branch only when the change is specific
to that flavor:

- `local-auth-custom-ui`: local authentication with custom UI
- `oauth-proxy`: OAuth proxy authentication with Carbon UI
- `oauth-proxy-custom-ui`: OAuth proxy authentication with custom UI
- `backend-only`: backend-only with database
- `backend-only-no-db`: backend-only without database

## Propagating Shared Changes

After a shared change is committed to `local-auth`, propagate only the relevant commit into the
other flavor branches, normally with `git cherry-pick`. The flavour histories were modernized
independently, so do not merge `local-auth` wholesale.

If target-specific conflict resolution materially changes the patch, use a descriptive commit
message that names the actual change:

```text
fix: quote shell variables in deployment scripts (oauth-proxy)
```

Avoid generic messages like:

```text
merge local-auth into oauth-proxy
```

## Maintenance Details

For the full flavor maintenance workflow, conflict-resolution rules, and validation
commands, see `.docs/maintenance.md`.
