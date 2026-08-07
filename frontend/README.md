# Frontend development

The React/Vite frontend uses the root environment contract. Install dependencies
with `npm --prefix frontend ci`, then start the complete OAuth development loop
from the repository root with `npm run dev`.

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

Run the real Dex/oauth2-proxy browser suite after starting the stack:

```bash
PLAYWRIGHT_EXTERNAL_SERVER=true npm run test:e2e
```

The suite reads its proxy URL and Dex credentials from the root `.env`, persists
the proxy session for authenticated projects, exercises item ownership and
sign-out, and probes header spoofing through real HTTP.
