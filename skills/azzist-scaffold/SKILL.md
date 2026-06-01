---
name: azzist-scaffold
description: >
  Scaffold a new project OR refactor an existing one to azzist standards. Serves as the base
  architecture layer for frontend, backend, database, cache, and queue services. v1 templates:
  Nuxt 3 (web). Use when the user wants to create a new project, says "azzist scaffold",
  OR when an existing project does not meet best-practice structure and needs to be aligned.
---

# azzist-scaffold

Two modes: **create** (new project from template) or **refactor** (align existing project to
azzist conventions). Both end with a locally-verified, deployable codebase.

## Mode detection

- No source code yet → **create mode**: copy templates, install, verify.
- Source exists but doesn't meet standard → **refactor mode**: audit, align, verify.

If uncertain, ask the user: "Start fresh or refactor existing code?"

## Stack routing (read `project.stack` from azzist.yaml)

Conventions are fixed — do not substitute without the user asking:

| Service             | Stack              | Status     |
|---------------------|--------------------|------------|
| Web / landing       | Nuxt 3             | v1 ready   |
| Backend API         | Go                 | planned    |
| Worker / background | Go + GoFiber       | planned    |
| Data / ML           | Python             | planned    |
| Database            | Postgres           | supported  |
| Cache / queue       | Redis              | supported  |
| Packaging           | Dockerfile per svc | all stacks |

For unimplemented stacks (go/gofiber/python), tell the user it is planned and scaffold the
directory structure + placeholder Dockerfile manually based on the conventions table.

## Create mode (Nuxt)

1. Copy `${CLAUDE_PLUGIN_ROOT}/templates/nuxt/` into the project root (or `./app/` per user
   preference). Copy `${CLAUDE_PLUGIN_ROOT}/templates/Dockerfile.nuxt` → `Dockerfile`.
2. Set the app title/landing copy from what the user described.
3. `npm install`.
4. Verify: `npm run dev`, confirm `http://localhost:3000`, then stop. Fix before proceeding.

## Refactor mode (any stack)

When azzist-analyze (or the user) flags that existing code doesn't meet standards, refactor
to align it. Principles:

- **Dockerfile required.** If absent, create one from the appropriate template. If present
  but bad (no multi-stage, runs as root, missing EXPOSE, missing healthz/readyz endpoint),
  fix it. Container must expose `/healthz` and `/readyz`.
- **Nuxt:** must use `nuxt.config.ts` (not .js), Nitro output, non-root user in Dockerfile,
  `NITRO_PORT=3000`. Static `nuxt generate` is NOT acceptable for server-rendered deploys.
- **Go:** `cmd/<app>/main.go` entry, `internal/` for private packages, no `init()` side
  effects, structured logger (slog or zerolog), `/healthz` + `/readyz` HTTP handlers.
- **Go+GoFiber:** same Go layout, Fiber v2+, graceful shutdown, single binary.
- **Python:** `pyproject.toml` with `[build-system]`, `src/` layout, `uvicorn`/`gunicorn`
  entrypoint, health endpoints.
- **Database (Postgres):** never hardcode DSN; read from env `DATABASE_URL`. Migrations
  tracked (sql files or a migration tool). No ORM magic that hides schema changes.
- **Cache/queue (Redis):** read URL from env `REDIS_URL`. Connection pool sized explicitly.
- **Secrets:** NEVER baked into image. All secrets via env vars. `.env.example` documents
  required vars (no values). `.env` is gitignored.

After each change, re-verify local boot/test. Never hand a broken refactor to deploy.

## Output

State mode (create/refactor), what changed, and the local smoke-test result.
