# Frontend development

This React 19/TypeScript/Vite frontend uses shadcn/ui, Tailwind CSS 4, TanStack Router/Query,
and the generated API client. Install only with npm.

Start the complete stack with the root quick-start sequence. Always browse through
`http://localhost:4180`; `http://localhost:5173` is only the proxy's Vite upstream. Login starts
at `/oauth2/sign_in`; logout uses `/oauth2/sign_out`. Proxy logout does not terminate the
upstream IdP SSO session, so the next login may be silent.

## Generated artifacts

```bash
npm run generate-client
npm run check:generated
```

Generation imports the backend directly and atomically updates `frontend/src/client` and
`frontend/src/routeTree.gen.ts`. Never edit them manually.

## Real-proxy Playwright

Start `npm run dev`, then either run a native browser:

```bash
PLAYWRIGHT_EXTERNAL_SERVER=true npm run test:e2e
```

or use the verified container wrapper when native browsers are missing/blocked:

```bash
npm run test:e2e:container
```

The wrapper derives the exact Playwright image version from the lockfile, mounts the checkout,
sets `PLAYWRIGHT_CONTAINER=true`, and traverses Dex, oauth2-proxy, secure cookies, logout, and
protected pages. Only container mode maps `localhost` to `host.docker.internal`; native runs do
not rewrite the hostname. A direct Vite or backend-only browser test is not an acceptable OAuth
check.

Run `npm run check`, `npm run build`, and `npm --prefix frontend audit` for frontend quality.
Biome covers the available ESLint equivalents; the remaining React Hooks 7 gaps are listed in
[the lint coverage note](../.docs/lint-coverage.md).
