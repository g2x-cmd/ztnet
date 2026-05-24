# AGENTS.md

## Project Shape
- Root app is a Pages Router Next.js 16 app in `src/`, with tRPC routers in `src/server/api/routers` wired through `src/server/api/root.ts` and `src/pages/api/trpc/[trpc].ts`.
- REST API routes live under `src/pages/api/v1`; auth is handled by Better Auth routes under `src/pages/api/auth`.
- `docs/` is a separate Docusaurus site with its own `package-lock.json`; run docs commands from `docs/`.
- `install.ztnet/` is a separate Express/TypeScript installer service with its own `package-lock.json`; run installer commands from `install.ztnet/`.

## Root App Commands
- Use npm, not pnpm/yarn; this repo commits `package-lock.json` lockfiles.
- Install with `npm install`; root `postinstall` runs `prisma generate`.
- Dev server: `npm run dev` or `npm run dev:webpack`.
- CI parity for app changes: `npm run lint`, `npm run format`, `npm run test`, then `npm run build`.
- `npm run lint` and `npm run format` both run Biome checks on `src`; use `npm run lint:fix` or `npm run format:fix` to write changes.
- There is no root typecheck script; use `npx tsc --noEmit` only when you intentionally need TypeScript verification beyond CI.

## Tests
- Full tests: `npm run test`; dev variant: `npm run test:dev`.
- Focus one page/component test with `npx jest --config jest.pages.config.ts path/to/file.test.tsx`.
- Focus one API/server/util test with `npx jest --config jest.api.config.ts path/to/file.test.ts`.
- Page tests match `**/__tests__/**/*.test.tsx` and use `jest-fixed-jsdom`; API tests match `src/server/api/__tests__`, `src/pages/api/__tests__`, and `src/utils/__tests__`.

## Env, Prisma, And Build Gotchas
- Next config imports `src/env.mjs` unless `SKIP_ENV_VALIDATION` is set; builds/tests need at least `DATABASE_URL`, `NEXTAUTH_URL`, and usually `NEXTAUTH_SECRET`.
- GitHub app workflows create a dummy `.env` with `DATABASE_URL=postgresql://postgres:postgres@localhost:5432/postgres?schema=public`, `NEXTAUTH_SECRET=dummy_key`, `NEXTAUTH_URL=http://localhost:3000`, `NEXT_PUBLIC_APP_VERSION=`, and `IS_GITHUB_ACTION=true`.
- Prisma config loads `.env`, uses schema folder `./prisma`, migrations in `prisma/migrations`, and seed command `tsx prisma/seed.ts`.
- Prisma uses PostgreSQL plus `MIGRATE_DATABASE_URL` as the shadow database URL; update `.env.example` and `src/env.mjs` together when adding env vars.
- `next.config.mjs` sets `output: "standalone"`; production start uses `node .next/standalone/server.js`, not `next start`.

## Style Notes
- Biome is configured for tabs, 90-column formatting, disabled import organization, and it ignores `install.ztnet/**/*`, `.devcontainer/**/*`, JS files, and locale JSON files.
- Biome treats `console.log`, explicit `any`, and unused variables as errors; existing `console.warn/error` usage is allowed.
- TypeScript is intentionally non-strict, allows/checks JS, uses `~/* -> src/*`, and excludes `docs`, `install.ztnet`, and `.next`.

## Docs And Installer
- Docs PR validation runs in `docs/`: `npm ci`, `npm install tailwindcss@3`, `npx docusaurus gen-api-docs all`, `npm run build`.
- Docs local server script is `npm start` and binds to `10.0.0.217:4000`; override or use `npm run build` when that host is unsuitable.
- Installer development uses `npm run start`; build uses `npm run build`; deployment mutates `install.ztnet/bash/ztnet.sh` with `INSTALLER_LAST_UPDATED` before restarting PM2.
