# Frontend development

This frontend uses React 19, TypeScript, Vite, TanStack Router/Query, shadcn/ui, and Tailwind
CSS 4. Dependencies are exact-pinned and managed only with npm.

## Install and run

```bash
npm ci
npm ci --prefix frontend
uv sync --project backend
cp .env.example .env
npm run dev
```

Open `http://localhost:5173`. Vite runs natively with HMR. To run only Vite against a compatible
API, use `npm --prefix frontend run dev` and configure `VITE_API_URL` in the root `.env`.

## Generated API client and routes

```bash
npm run generate-client
npm run check:generated
```

Generation imports the backend application directly, needs no running API or network download,
and atomically updates `frontend/src/client` plus `frontend/src/routeTree.gen.ts`. Never edit
those outputs manually. When only file routes change, use
`npm --prefix frontend run generate-routes`.

## Playwright

Start `npm run dev` in one terminal. Native browsers can run with:

```bash
PLAYWRIGHT_EXTERNAL_SERVER=true npm run test:e2e
```

If local browser binaries are missing or macOS blocks browser launch, use the verified
containerized pattern in a second terminal:

```bash
docker run --rm --network host --ipc=host \
  -v "$PWD:/work" -w /work/frontend \
  -e PLAYWRIGHT_EXTERNAL_SERVER=true \
  -e PLAYWRIGHT_CONTAINER=true \
  mcr.microsoft.com/playwright:v1.62.1-noble \
  npx playwright test
```

The image version must match `@playwright/test` in `frontend/package-lock.json`.
`PLAYWRIGHT_CONTAINER=true` maps container `localhost` to the host application; native runs do not
apply that rewrite. The suite covers login/logout, protected routes, settings, signup, and
light/dark/system theme persistence.

## Quality

```bash
npm run check
npm run build
npm --prefix frontend audit
```

Tailwind CSS 4 is configured in CSS and through the Vite plugin. Shared UI primitives live
under `src/components/ui`. Keep protected routes below `src/routes/_layout` and use the generated client with
TanStack Query for ordinary API calls. See [known lint coverage gaps](../.docs/lint-coverage.md)
for the React Hooks rules that Biome cannot currently reproduce.
