---
name: azzist-scaffold
description: >
  Scaffold a new project from azzist's opinionated templates and verify it runs locally
  before any deploy. v1 supports the Nuxt 3 web stack. Use when the user wants to create a
  website/landing page with azzist, says "azzist scaffold", or after azzist-init when the
  project source does not exist yet.
---

# azzist-scaffold

Create a clean, conventional project from `azzist.yaml` and prove it boots locally.

## Stack routing (read `project.stack` from azzist.yaml)

- **nuxt** (v1, supported): web frontend / landing page.
- **go**: backend API — clean structure. *(not yet templated — tell the user it is planned)*
- **gofiber**: worker on GoFiber. *(planned)*
- **python**: data-related work, tidy structure. *(planned)*

Conventions are fixed: web=Nuxt, backend=Go, worker=Go+GoFiber, data=Python,
db=Postgres, cache/queue=Redis. Do not substitute stacks without the user asking.

## Nuxt steps

1. Copy `${CLAUDE_PLUGIN_ROOT}/templates/nuxt/` into the project (e.g. `./app/` or repo
   root per the user's preference). Copy `${CLAUDE_PLUGIN_ROOT}/templates/Dockerfile.nuxt`
   to the project as `Dockerfile`.
2. Set the app title/landing copy from what the user described.
3. Install deps: `npm install`.
4. Verify local dev boots: run `npm run dev`, confirm it serves on `http://localhost:3000`,
   then stop it. If it fails, fix before proceeding — never hand a broken scaffold to deploy.
5. Tell the user the project is ready and the next step is `azzist-deploy`.

## Output

State what was created, where, and the result of the local `npm run dev` smoke test.
