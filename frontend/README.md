# FastAPI Project — Frontend

The frontend uses React, TypeScript, Vite, TanStack Query and Router, IBM Carbon, and
Tailwind CSS 4. Direct dependencies are exact-pinned and the lockfile is managed by npm.

## Install dependencies

From the repository root, install the root and frontend dependencies with npm:

```bash
npm ci
npm --prefix frontend ci
```

Node.js 20.19 or newer is required. If you use nvm, the frontend includes an `.nvmrc`
file:

```bash
cd frontend
nvm install
nvm use
```

## Frontend development

Start the complete development stack from the repository root:

```bash
npm run dev
```

This starts PostgreSQL and Adminer in Compose, then runs the FastAPI backend and Vite
natively with reload/HMR. Open http://localhost:5173/. See
[`../.docs/development.md`](../.docs/development.md) for ports and troubleshooting.

To run Vite by itself when a compatible backend is already available:

```bash
npm --prefix frontend run dev
```

Vite loads environment variables from the repository root. Set `VITE_API_URL` in the
root `.env` when the API is not served through the same origin.

## Generate client and routes

Generate the OpenAPI document, TypeScript client, and route tree through the offline
root pipeline:

```bash
npm run generate-client
```

The command derives OpenAPI directly from the backend application, so no running API or
network download is required. Never edit `src/client/` or `src/routeTree.gen.ts`
manually. Verify generated artifacts with:

```bash
npm run check:generated
```

Run `npm --prefix frontend run generate-routes` when only route source files changed.

## Code structure

- `frontend/src/client` — generated OpenAPI client
- `frontend/src/components` — shared and feature components
- `frontend/src/hooks` — custom hooks
- `frontend/src/routes` — TanStack file routes
- `frontend/src/styles` — Carbon SCSS and Tailwind CSS theme bridge

## Styling and themes

Carbon component styles remain in `src/styles/carbon.scss`. Tailwind 4 is configured in
CSS through `src/styles/index.css` and the `@tailwindcss/vite` plugin; there is no
Tailwind JavaScript configuration or PostCSS configuration. The token bridge in
`src/styles/themes/carbon.css` maps Tailwind utilities to active Carbon tokens.

Theme selection supports light, dark, and system settings, persists under
`vite-ui-theme`, and resolves to Carbon `g10` or `g90`. Keep Carbon components from
`@carbon/react`, icons from `@carbon/icons-react`, and use Tailwind utilities for layout
and theme-aware token colors.

## Using a remote API

Set `VITE_API_URL` in the repository root `.env`:

```env
VITE_API_URL=https://api.my-domain.example.com
```

## End-to-end testing with Playwright

Start the development stack in one terminal:

```bash
npm run dev
```

Then run the Chromium suite from another terminal:

```bash
npm run test:e2e
```

For interactive Playwright UI mode:

```bash
npm --prefix frontend exec playwright test --ui
```

If native browser binaries are unavailable, run the matching
`mcr.microsoft.com/playwright` image and forward ports 5173 and 8000 to the host. The
image tag must match the exact `@playwright/test` version in `package.json`.

## Verification

From the repository root:

```bash
npm run check
npm run verify
npm --prefix frontend audit
```

## Removing the frontend

For an API-only application, remove `frontend` and the frontend service from deployment
configuration. You can also remove unused `FRONTEND` environment variables from local
and deployment environment files.
