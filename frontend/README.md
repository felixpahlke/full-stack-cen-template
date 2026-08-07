# FastAPI Project — Frontend

The frontend uses React, TypeScript, Vite, TanStack Query and Router, shadcn/ui with
Radix primitives, and Tailwind CSS 4. Direct dependencies are exact-pinned and the
lockfile is managed by npm.

## Install dependencies

From the repository root, install the root and frontend dependencies with npm:

```bash
npm ci
npm --prefix frontend ci
```

Node.js 20.19 or newer is required. If you use nvm, the frontend includes an
`.nvmrc` file:

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

## Generate Client

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

## Code Structure

The frontend code is structured as follows:

- `frontend/src` - The main frontend code.
- `frontend/src/assets` - Static assets.
- `frontend/src/client` - The generated OpenAPI client.
- `frontend/src/components` - The different components of the frontend.
- `frontend/src/hooks` - Custom hooks.
- `frontend/src/routes` - The different routes of the frontend which include the pages.

## Styling and themes

Tailwind 4 is configured in CSS through `src/styles/index.css`; there is no
`tailwind.config.js` or PostCSS configuration. The shadcn `new-york` color tokens live
in `src/styles/themes/neutral.css`. Theme selection supports light, dark, and system
settings and persists under `vite-ui-theme` in local storage.

## Using a Remote API

Set `VITE_API_URL` in the repository root `.env`:

```env
VITE_API_URL=https://api.my-domain.example.com
```

Then, when you run the frontend, it will use that URL as the base URL for the API.

## End-to-End Testing with Playwright

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

### Removing the frontend

If you are developing an API-only app and want to remove the frontend, you can do it easily:

- Remove the `./frontend` directory.

- In the `docker-compose.yml` file, remove the whole service / section `frontend`.

Done, you have a frontend-less (api-only) app. 🤓

---

If you want, you can also remove the `FRONTEND` environment variables from:

- `.env`
- `./scripts/*.sh`

But it would be only to clean them up, leaving them won't really have any effect either way.
