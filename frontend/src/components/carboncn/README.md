# CarbonCN

[CarbonCN](https://www.carboncn.dev/) provides source-owned components that can complement the
standard Carbon React package. Its site and component catalog remain available.

Run the CLI from `frontend` so it reads `components.json`:

```bash
cd frontend
pnpm dlx carboncn add button
```

Generated components go to `src/components/carboncn` and may use `@/lib/utils`. Review generated
dependencies before committing them and keep every direct dependency exact-pinned with pnpm.

This template uses Tailwind CSS 4, so `components.json` intentionally has an empty Tailwind config
path and points at `src/styles/index.css`. Do not recreate `tailwind.config.js`; theme tokens belong
in CSS through `@theme` and the existing Carbon theme variables.
