---
name: azzist
description: >
  End-to-end project shipping: scaffold a stack, dockerize, deploy over SSH into an isolated
  Docker network, wire a reverse proxy (nginx or existing Traefik), and attach a public domain
  via Cloudflare — all without disturbing existing server services. Use when the user wants to
  build AND deploy something live, says "azzist", "ship this e2e", "deploy a landing page",
  "make it public", or asks for a full develop->deploy flow.
---

# azzist (orchestrator)

Drive a project from idea to public URL by running the focused sub-skills in order. Each
stage has its own skill; invoke them as you reach that stage.

## Stack conventions (do not deviate unless the user asks)

| Need                     | Stack                  |
|--------------------------|------------------------|
| Web frontend / landing   | Nuxt 3                 |
| Backend API              | Go                     |
| Worker / background jobs | Go + GoFiber           |
| Data-related work        | Python (tidy structure)|
| Database                 | Postgres               |
| Cache / queue            | Redis                  |
| Packaging                | Dockerfile per service |
| Reverse proxy            | nginx (or existing Traefik) |

v1 implements the **Nuxt web** golden path end-to-end. Other stacks are scaffold-planned.

## Flow

1. **Config** — if `azzist.yaml` is absent, run **azzist-init** to create `azzist.yaml`
   (committed) and `azzist.local.yaml` (gitignored secrets). Make sure the user has filled
   the domain, Cloudflare token/zone, and server SSH details before any remote step.
2. **Scaffold** — run **azzist-scaffold** to generate the project and confirm `npm run dev`
   works locally.
3. **Deploy** — run **azzist-deploy** to build the image, smoke-test it, and run it isolated
   on the server (`azzist_<name>` network, private port). **Pause and confirm with the user
   before this first remote/destructive step** (it installs Docker if missing and runs
   containers on their server).
4. **Server** — run **azzist-server** to wire the proxy non-invasively (Traefik labels or an
   isolated nginx vhost), upsert the Cloudflare A record, and provision TLS.

## Isolation contract (applies to every stage)

- Touch only resources named `azzist_<name>*`. Never stop, remove, or reconfigure existing
  containers, networks, proxies, or services. If something unexpected blocks you, ask the
  user instead of forcing past it.
- Existing Traefik is integrated via labels only — never reconfigured.
- Secrets stay in `azzist.local.yaml`; never commit them.

## E2E success check

The flow is done when:
```
curl -fsS -I https://<domain>
```
returns `200` (or `301` to https) and the site is publicly reachable. Report the public URL,
the proxy strategy used, the chosen port, and the Cloudflare record result.
