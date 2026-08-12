---
name: add-page
description: Add a protected shadcn page with a TanStack file route, header navigation, and generated-client data fetching.
---

# Add a page

Read `frontend/src/routes/_layout/index.tsx` and a comparable existing page first. If the request
introduces a database entity or API surface, use `add-resource` before this skill.

1. Create `frontend/src/routes/_layout/<name>.tsx` and export
   `createFileRoute("/_layout/<name>")`. This inherits the proxy-protected shell from
   `_layout.tsx`; oauth2-proxy, not a browser bearer token, owns entry and logout.
2. Add `{ title, path }` to `navItems` in `frontend/src/components/common/Header.tsx`. Hiding a
   link is not authorization; enforce access in the backend.
3. Fetch server data with TanStack Query and the generated service/types from `@/client`. Use a
   stable query key, throw or surface request failures through the existing error/toast helpers,
   and invalidate the affected keys after mutations.
4. Compose the existing shadcn/ui primitives under `frontend/src/components/ui`. Use semantic
   Tailwind theme classes such as `bg-background` and `text-muted-foreground`; avoid hardcoded
   colors and do not recreate owned primitives inline.
5. Run `pnpm run generate-client` to regenerate the route tree. Never edit
   `frontend/src/routeTree.gen.ts` or `frontend/src/client` manually.

During template maintenance, add the same route to the Carbon `oauth-proxy` twin; that branch's
parity gate deliberately keeps both route surfaces equal.

Done means navigation works, loading/empty/error states are intentional, and `pnpm run verify`
passes.
