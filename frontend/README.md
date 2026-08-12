# Frontend development

This frontend uses React 19, TypeScript, Vite, TanStack Router/Query, shadcn/ui, and Tailwind
CSS 4. Dependencies are exact-pinned and managed through the root pnpm workspace.

## Install and run

```bash
corepack enable pnpm
pnpm install
uv sync --project backend
cp .env.example .env
pnpm run dev
```

Open `http://localhost:5173`. Vite runs natively with HMR. To run only Vite against a compatible
API, use `pnpm --filter frontend run dev` and configure `VITE_API_URL` in the root `.env`.

## Generated API client and routes

```bash
pnpm run generate-client
pnpm run check:generated
```

Generation imports the backend application directly, needs no running API or network download,
and atomically updates `frontend/src/client` plus `frontend/src/routeTree.gen.ts`. Never edit
those outputs manually. When only file routes change, use
`pnpm --filter frontend run generate-routes`.

## Playwright

Start `pnpm run dev` in one terminal. Native browsers can run with:

```bash
PLAYWRIGHT_EXTERNAL_SERVER=true pnpm run test:e2e
```

If local browser binaries are missing or macOS blocks browser launch, use the verified
container wrapper in a second terminal:

```bash
pnpm run test:e2e:container
```

The wrapper selects Docker or Podman and reads the exact Playwright image version from the
`@playwright/test` pin in `frontend/package.json`.
`PLAYWRIGHT_CONTAINER=true` maps container `localhost` to the host application; native runs do not
apply that rewrite. The suite covers login/logout, protected routes, settings, signup, and
light/dark/system theme persistence.

## Quality

```bash
pnpm run check
pnpm run build
pnpm --filter frontend audit
```

Tailwind CSS 4 is configured in CSS and through the Vite plugin. Shared UI primitives live
under `src/components/ui`. Keep protected routes below `src/routes/_layout` and use the generated client with
TanStack Query for ordinary API calls. See [known lint coverage gaps](../.docs/lint-coverage.md)
for the React Hooks rules that Biome cannot currently reproduce.
