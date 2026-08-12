---
name: add-page
description: Add a protected Carbon page with a TanStack file route, header navigation, and generated-client data fetching.
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
4. Use IBM Carbon components and semantic Carbon tokens. Use Tailwind only for layout, spacing,
   and the existing token bridge. Reuse components rather than recreating controls inline.
5. Run `pnpm run generate-client` to regenerate the route tree. Never edit
   `frontend/src/routeTree.gen.ts` or `frontend/src/client` manually.

6. Update the expected route list in `scripts/route-parity.test.mjs`. Template maintenance must add
   the same page to `oauth-proxy-custom-ui`; the test deliberately keeps both route surfaces equal.

Done means navigation works, loading/empty/error states are intentional, and `pnpm run verify`
passes.
