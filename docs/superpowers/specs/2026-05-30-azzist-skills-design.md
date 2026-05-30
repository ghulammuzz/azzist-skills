# azzist-skills — Design Spec

Date: 2026-05-30
Status: Approved (design), pending implementation plan

## Context

The user wants a Claude Code skill plugin named `azzist` that integrates all the
"vibecoding" tooling needed to take a project end-to-end: scaffold → develop →
test → deploy to a public URL. One command flow should be able to produce, e.g.,
a Nuxt landing page that is built into a Docker image, shipped to a server over
SSH, fronted by a reverse proxy, given a domain via Cloudflare DNS, and reachable
publicly over HTTPS.

The plugin will be published to a **public** GitHub repo and installed via the
Claude Code plugin marketplace, so secrets must never live in committed files.

### Stack conventions (opinionated defaults)
- Web frontend → **Nuxt** (Nuxt 3).
- Backend API → **Go**.
- Worker → **Go + GoFiber**.
- Data-related work → **Python**.
- Database → **Postgres** (priority).
- Caching / queue → **Redis**.
- Deployment → **Dockerfile** per service.
- Reverse proxy → **nginx** by default, but auto-detect existing proxy.
- Clean, conventional project structure for each stack.

### Hard constraint: isolation, zero interference
The target server may already run other services — including **Traefik in
Docker**. The skill MUST NOT touch, reconfigure, or disrupt anything already on
the server. Everything we deploy is isolated (own Docker network, namespaced
container names, own proxy vhost file or Traefik labels only).

## Scope

**v1 (this spec): the golden path.**
`init → scaffold (Nuxt) → docker build + local test → ssh deploy (isolated) →
proxy wired → Cloudflare A record → public HTTPS reachable`.

Later (out of scope for v1, but architecture must leave room): Go API, GoFiber
worker, Python data scaffolds; Postgres/Redis provisioning beyond the opt-in
container hooks.

## Distribution

Public git repo `azzist-skills`. Standard Claude Code plugin layout. Users
install with:
```
/plugin marketplace add <github-owner>/azzist-skills
/plugin install azzist
```

## Repo layout

```
azzist-skills/
  .claude-plugin/
    plugin.json          # name, description, author
    marketplace.json     # marketplace entry
  skills/
    azzist/SKILL.md          # orchestrator: runs init→scaffold→deploy→server E2E
    azzist-init/SKILL.md     # generate config skeleton + gitignore secrets
    azzist-scaffold/SKILL.md # v1: Nuxt. Later: Go, GoFiber worker, Python
    azzist-deploy/SKILL.md   # docker build, ship over ssh, run container
    azzist-server/SKILL.md   # port scan, proxy detect, nginx/traefik, cf DNS
  templates/
    nuxt/                 # Nuxt scaffold skeleton
    Dockerfile.nuxt
    nginx.vhost.conf.tmpl
  scripts/
    free-port.sh          # find unused host port on server
    detect-proxy.sh       # detect nginx host / traefik container / none
    cf-dns.sh             # upsert Cloudflare A record
    ssh-helpers.sh        # ssh/scp wrappers honoring auth mode
  README.md
```

## Skills breakdown (several focused skills)

- **azzist** (orchestrator) — entry point. Reads config, drives the full E2E
  flow by delegating to the sub-skills in order. Knows the stack conventions.
- **azzist-init** — generates `azzist.yaml` (committed skeleton with
  placeholders) and `azzist.local.yaml` (gitignored secrets), and ensures
  `.gitignore` excludes the local file.
- **azzist-scaffold** — scaffolds the project from templates. v1: Nuxt. Produces
  a clean, conventional structure and a working local dev (`nuxt dev`).
- **azzist-deploy** — builds the Docker image, ships it to the server over SSH
  (image transfer or remote build), runs the container in an isolated network on
  a free/assigned port.
- **azzist-server** — server-side concerns: free-port scan, reverse-proxy
  detection + non-invasive wiring, Cloudflare DNS upsert, TLS.

## Config schema

`azzist.yaml` — committed, placeholders only:
```yaml
project:
  name: my-landing
  stack: nuxt           # v1: nuxt
domain: landing.example.com
deploy:
  proxy: auto           # auto | nginx | traefik
  port: auto            # auto | <number>
  server: prod          # references a server entry in azzist.local.yaml
database: none          # none | postgres
cache: none             # none | redis
```

`azzist.local.yaml` — **gitignored**, real secrets:
```yaml
cloudflare:
  api_token: "..."
  zone_id: "..."
servers:
  prod:
    host: 1.2.3.4
    ssh_user: root
    auth: ssh_config      # ssh_config | key | password
    ssh_alias: myserver   # when auth: ssh_config
    # key_path: ~/.ssh/id_ed25519   # when auth: key
    # password: "..."               # when auth: password (discouraged)
```

Security rules:
- Secrets only in `azzist.local.yaml`; never committed. `azzist-init` writes the
  `.gitignore` entry before anything else.
- Prefer `ssh_config` alias or key auth over password.
- Cloudflare token scoped to DNS edit on the one zone.

## Isolation & deploy strategy

- **Per-project Docker network** `azzist_<name>`; containers named
  `azzist_<name>_app` (and `_db`, `_cache` when enabled). Never read/modify other
  containers, networks, or proxy configs.
- **Free port**: `detect-proxy.sh`/`free-port.sh` scans the server for an unused
  host port; or honor a manual `deploy.port`.
- **Proxy `auto` detection**:
  - **Traefik container running** → attach app container to Traefik's network and
    add Docker labels (`Host(domain)` rule). No config-file edits — Traefik
    auto-discovers. Fully non-invasive.
  - **Host nginx present** → write ONE isolated vhost file in `conf.d`
    (namespaced by project), run `nginx -t`, reload. Only our file is touched.
  - **Neither** → install nginx (detect + install), then proceed as host-nginx.
- **Cloudflare**: upsert an A record `domain → server IP` via API.
- **TLS**: nginx path uses certbot; Traefik path relies on Traefik's existing
  certificate resolver (do not reconfigure it). v1 documents the assumption.
- **DB/cache** (opt-in): Postgres / Redis run as isolated containers in the
  project network, not shared with anything else on the host.

## E2E verification (golden path)

1. `azzist-init` → `azzist.yaml` + gitignored `azzist.local.yaml` created.
2. `azzist-scaffold` → Nuxt project; `nuxt dev` serves locally.
3. `azzist-deploy` → `docker build`, run container locally, smoke test.
4. `azzist-deploy` → ship over SSH; container up on isolated network + free port.
5. `azzist-server` → proxy wired (nginx vhost or Traefik labels), Cloudflare A
   record set.
6. `curl https://<domain>` returns 200 — site is public.

## Open items deferred to plan
- Image transfer mechanism: `docker save | ssh docker load` vs registry vs remote
  build. Decide in implementation plan.
- certbot automation details for the nginx path.
- Exact Nuxt template contents.
