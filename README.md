# azzist

End-to-end vibecoding toolkit for **Claude Code**. One flow takes a project from idea to a
public URL: **scaffold → dockerize → deploy over SSH → reverse proxy → Cloudflare DNS →
public HTTPS** — without ever disturbing services already running on your server.

## What it does

- Scaffolds an opinionated, clean project (v1: a Nuxt 3 landing page).
- Builds a Docker image and smoke-tests it locally.
- Ships it to your server over SSH and runs it in an **isolated** Docker network.
- Fronts it with a reverse proxy: integrates with an **existing Traefik** via labels, or
  writes a single isolated **nginx** vhost (installs nginx only if none exists).
- Attaches a domain via the **Cloudflare** API and provisions TLS.

## Stack conventions

| Need                     | Stack                       |
|--------------------------|-----------------------------|
| Web frontend / landing   | Nuxt 3                      |
| Backend API              | Go                          |
| Worker / background jobs | Go + GoFiber                |
| Data-related work        | Python                      |
| Database                 | Postgres                    |
| Cache / queue            | Redis                       |
| Packaging                | Dockerfile per service      |
| Reverse proxy            | nginx, or existing Traefik  |

v1 implements the **Nuxt web** path end-to-end. Other stacks are planned.

## Install

```
/plugin marketplace add ghulammuzz/azzist-skills
/plugin install azzist
```

Then just ask Claude to ship something, e.g. *"use azzist to deploy a landing page at
landing.example.com"*. The `azzist` orchestrator skill runs the sub-skills in order:
`azzist-init` → `azzist-scaffold` → `azzist-deploy` → `azzist-server`.

## Configuration (secret-safe by design)

azzist splits config into two files so you can keep a project in a **public** repo:

- **`azzist.yaml`** — committed, placeholders only (project, domain, deploy options).
- **`azzist.local.yaml`** — **gitignored**, holds secrets (Cloudflare token, SSH creds).

`azzist-init` generates both and adds `azzist.local.yaml` to `.gitignore` before writing it.

`azzist.yaml`:
```yaml
project: { name: my-landing, stack: nuxt }
domain: landing.example.com
deploy: { proxy: auto, port: auto, server: prod }   # proxy: auto|nginx|traefik
database: none   # none|postgres
cache: none      # none|redis
```

`azzist.local.yaml` (never committed):
```yaml
cloudflare: { api_token: "...", zone_id: "..." }
servers:
  prod:
    host: 1.2.3.4
    ssh_user: root
    auth: ssh_config        # ssh_config | key | password
    ssh_alias: myserver     # or key_path: ~/.ssh/id_ed25519
```

SSH auth preference: `ssh_config` alias > `key` > `password` (password needs `sshpass`).
Cloudflare token should be scoped to **Zone.DNS Edit** on the one zone.

## Isolation guarantees

azzist only ever creates/modifies resources named `azzist_<project>*`:

- Docker network `azzist_<name>`, containers `azzist_<name>_app` / `_db` / `_cache`.
- It never stops, removes, or reconfigures containers, networks, or proxies it didn't create.
- An existing **Traefik** is integrated via Docker labels only — its config is never touched.
- nginx integration is a single isolated vhost in `conf.d/azzist_<name>.conf`.

If azzist hits something unexpected on your server, it stops and asks rather than forcing past it.

## End-to-end walkthrough (landing page)

1. **Init** — `azzist-init` writes `azzist.yaml` + gitignored `azzist.local.yaml`; you fill
   domain, Cloudflare token/zone, and server SSH details.
2. **Scaffold** — `azzist-scaffold` copies the Nuxt template and verifies `npm run dev`.
3. **Deploy** — `azzist-deploy` builds the image, smoke-tests locally, then (after your
   confirmation) ships it over SSH and runs it isolated on a free private port.
4. **Server** — `azzist-server` detects the proxy, wires it non-invasively, upserts the
   Cloudflare A record, and provisions TLS.
5. **Done** — `curl -I https://<domain>` returns `200` and your site is live.

## Layout

```
.claude-plugin/   plugin.json + marketplace.json
skills/           azzist, azzist-init, azzist-scaffold, azzist-deploy, azzist-server
templates/        nuxt/, Dockerfile.nuxt, nginx.vhost.conf.tmpl, config/
scripts/          ssh-helpers.sh, free-port.sh, detect-proxy.sh, cf-dns.sh
```

## Requirements

- Local: Docker, `git`, `curl`, `jq` (and `sshpass` only if you use password auth).
- Server: SSH access; Docker (azzist installs it if missing, with your confirmation).
- A Cloudflare-managed domain.
