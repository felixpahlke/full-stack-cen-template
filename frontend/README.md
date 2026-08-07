# Frontend development

The frontend uses React, TypeScript, Vite, TanStack Query and Router, shadcn/ui with
Radix primitives, and Tailwind CSS 4. Direct dependencies are exact-pinned and the
lockfile is managed by npm. Node.js 20.19 or newer is required.

Install the root and frontend dependencies from the repository root:

```bash
npm ci
npm --prefix frontend ci
```

Then start the complete OAuth development loop with `npm run dev`.

The browser entry is the oauth2-proxy URL derived from `OAUTH2_PROXY_PORT`; Vite's
native port is an internal development upstream. Same-origin `/api` requests are
proxied by Vite to the loopback FastAPI process while preserving the identity
headers stamped by oauth2-proxy.

Generate the API client from the repository root:

```bash
npm run generate-client
```

Generation is offline and does not require `.env`, a running backend, or Docker.
Do not edit `frontend/src/client` manually.

Run `npm --prefix frontend run generate-routes` when only route source files change.

## Styling and themes

Tailwind 4 is configured through `src/styles/index.css` and the
`@tailwindcss/vite` plugin; there is no Tailwind configuration file or PostCSS
configuration. The shadcn `new-york` color tokens live in
`src/styles/themes/neutral.css`. Theme selection supports light, dark, and system
settings and persists under `vite-ui-theme` in local storage.

## Verification

Run the environment-independent checks without a root `.env`:

```bash
npm run verify
npm --prefix frontend audit
```

The real Dex/oauth2-proxy browser suite requires the development environment and
its root `.env`. Start the stack, then run:

```bash
PLAYWRIGHT_EXTERNAL_SERVER=true npm run test:e2e
```

If the native browser cannot launch, use the matching containerized browser with
`npm run test:e2e:container` while the development stack is running.

The suite reads its proxy URL and Dex credentials from the root `.env`, persists
the proxy session for authenticated projects, exercises item ownership and
sign-out, and probes header spoofing through real HTTP.
