# azzist-skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Build the `azzist` Claude Code plugin that takes a project E2E (scaffold → docker → ssh deploy → reverse-proxy → Cloudflare DNS → public HTTPS), with strict server isolation.

**Architecture:** A public plugin repo with one orchestrator skill (`azzist`) and four focused sub-skills (`azzist-init`, `azzist-scaffold`, `azzist-deploy`, `azzist-server`). Skills are markdown instructions Claude follows; shared shell scripts under `scripts/` do the deterministic server work (port scan, proxy detect, Cloudflare upsert, ssh). Config is split: committed `azzist.yaml` skeleton + gitignored `azzist.local.yaml` secrets.

**Tech stack:** Claude Code plugin format, bash scripts, Docker, nginx/Traefik, Cloudflare API, Nuxt 3 (v1 scaffold).

**Verification model:** No unit-test framework — artifacts are skill docs + bash. Verify each task with: `bash -n` syntax check + `shellcheck` (if available) on scripts, valid JSON (`jq .`) on plugin manifests, and a final manual install smoke test in Claude Code.

---

### Task 1: Repo skeleton + plugin manifests

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `.claude-plugin/marketplace.json`
- Create: `.gitignore`
- Create: `README.md` (stub, expanded in Task 8)

- [ ] **Step 1:** Write `.claude-plugin/plugin.json` — `name: azzist`, description, author (ghulammuzz). No hooks needed.
- [ ] **Step 2:** Write `.claude-plugin/marketplace.json` — single plugin entry, `source: ./`, category `productivity`.
- [ ] **Step 3:** Write `.gitignore` — exclude `azzist.local.yaml`, `**/azzist.local.yaml`, `*.local.yaml`.
- [ ] **Step 4:** Verify manifests are valid JSON: `jq . .claude-plugin/plugin.json && jq . .claude-plugin/marketplace.json`. Expected: pretty-printed, exit 0.
- [ ] **Step 5:** `git init` (repo root is the plugin), commit `chore: scaffold azzist plugin skeleton`.

---

### Task 2: azzist-init skill + config templates

**Files:**
- Create: `skills/azzist-init/SKILL.md`
- Create: `templates/config/azzist.yaml` (committed skeleton, placeholders)
- Create: `templates/config/azzist.local.yaml.example` (secrets template)

- [ ] **Step 1:** Write `templates/config/azzist.yaml` per spec schema (project, domain, deploy{proxy,port,server}, database, cache).
- [ ] **Step 2:** Write `azzist.local.yaml.example` per spec (cloudflare{api_token,zone_id}, servers map with auth modes ssh_config|key|password).
- [ ] **Step 3:** Write `SKILL.md`: frontmatter (name `azzist-init`, description with triggers). Body: (1) FIRST ensure `.gitignore` excludes `azzist.local.yaml`; (2) copy skeleton → `azzist.yaml`; (3) copy example → `azzist.local.yaml` and prompt user to fill secrets; (4) security warning never to commit local file.
- [ ] **Step 4:** Verify frontmatter valid: `head -5 skills/azzist-init/SKILL.md` shows `---`/name/description.
- [ ] **Step 5:** Commit `feat(init): config skeleton + secret-split init skill`.

---

### Task 3: Shared server scripts

**Files:**
- Create: `scripts/ssh-helpers.sh` (sourceable: `azzist_ssh`, `azzist_scp` honoring auth: ssh_config alias | key_path | password via sshpass)
- Create: `scripts/free-port.sh` (scan remote for unused host port in a range, echo first free)
- Create: `scripts/detect-proxy.sh` (echo `traefik` if a traefik container runs, else `nginx` if host nginx present, else `none`)
- Create: `scripts/cf-dns.sh` (upsert A record via Cloudflare API: GET record id, PUT if exists else POST)

- [ ] **Step 1:** Write `ssh-helpers.sh` — functions dispatch on `$AZZIST_SSH_AUTH`. ssh_config → `ssh <alias>`; key → `ssh -i <key> user@host`; password → `sshpass -p`. Guard: warn if sshpass missing.
- [ ] **Step 2:** Write `free-port.sh` — `azzist_ssh "ss -tlnH"` parse used ports, return first free in 8000-8999 (or arg range).
- [ ] **Step 3:** Write `detect-proxy.sh` — remote `docker ps --format '{{.Image}}'` grep traefik; else `command -v nginx`; echo result.
- [ ] **Step 4:** Write `cf-dns.sh` — args zone_id, token, name, ip. curl Cloudflare v4 API, idempotent upsert. Quote all vars (no injection).
- [ ] **Step 5:** Syntax check all: `for f in scripts/*.sh; do bash -n "$f"; done` (expect exit 0). Run `shellcheck scripts/*.sh` if available; fix warnings.
- [ ] **Step 6:** Commit `feat(scripts): ssh/free-port/proxy-detect/cloudflare helpers`.

---

### Task 4: azzist-scaffold skill + Nuxt template + Dockerfile

**Files:**
- Create: `skills/azzist-scaffold/SKILL.md`
- Create: `templates/nuxt/` (minimal Nuxt 3 landing skeleton: package.json, nuxt.config.ts, app.vue, pages/index.vue, .dockerignore)
- Create: `templates/Dockerfile.nuxt` (multi-stage: node build → node runtime, `node .output/server/index.mjs`, EXPOSE 3000)

- [ ] **Step 1:** Write Nuxt template files (clean conventional structure, a real landing page in `pages/index.vue`).
- [ ] **Step 2:** Write `Dockerfile.nuxt` multi-stage, non-root, production `NITRO_PORT`/`HOST=0.0.0.0`.
- [ ] **Step 3:** Write `SKILL.md`: read `azzist.yaml` stack; if `nuxt`, copy template, `npm install`, confirm `npm run dev` works locally before deploy. Note where future stacks (go/gofiber/python) plug in.
- [ ] **Step 4:** Verify Dockerfile parses: `docker build -f templates/Dockerfile.nuxt --help` no-op OR visual review (no docker build of empty ctx). Lint template package.json with `jq .`.
- [ ] **Step 5:** Commit `feat(scaffold): nuxt v1 template + dockerfile + scaffold skill`.

---

### Task 5: azzist-deploy skill

**Files:**
- Create: `skills/azzist-deploy/SKILL.md`

- [ ] **Step 1:** Write `SKILL.md` flow: (1) `docker build` local image `azzist_<name>_app`; (2) local smoke test `docker run` + curl; (3) ensure remote docker present (detect, install if missing — never touch existing); (4) transfer image `docker save | azzist_ssh docker load`; (5) create isolated network `azzist_<name>` if absent; (6) resolve port via `free-port.sh` or manual; (7) `docker run -d --name azzist_<name>_app --network azzist_<name> -p <port>:3000 --restart unless-stopped`; (8) verify `curl localhost:<port>` on server.
- [ ] **Step 2:** Add isolation guardrails in prose: never `docker rm`/modify containers not prefixed `azzist_<name>`; never edit existing networks.
- [ ] **Step 3:** Verify frontmatter + `head` check.
- [ ] **Step 4:** Commit `feat(deploy): docker build + isolated ssh deploy skill`.

---

### Task 6: azzist-server skill + nginx vhost template

**Files:**
- Create: `skills/azzist-server/SKILL.md`
- Create: `templates/nginx.vhost.conf.tmpl` (`__DOMAIN__`, `__PORT__` placeholders, proxy_pass to 127.0.0.1:port)

- [ ] **Step 1:** Write `nginx.vhost.conf.tmpl` — server_name `__DOMAIN__`, location / proxy to `127.0.0.1:__PORT__`, websocket upgrade headers.
- [ ] **Step 2:** Write `SKILL.md` proxy logic via `detect-proxy.sh`:
  - `traefik` → re-run app container with Traefik labels on Traefik's network (Host rule = domain). No file edits.
  - `nginx` → render vhost (sed placeholders), write to `conf.d/azzist_<name>.conf` ONLY, `nginx -t`, reload.
  - `none` → install nginx, then nginx path.
- [ ] **Step 3:** Cloudflare: call `cf-dns.sh` to upsert A record domain→server IP.
- [ ] **Step 4:** TLS: nginx path → certbot `--nginx -d domain`; traefik path → rely on existing resolver (document, don't reconfigure).
- [ ] **Step 5:** Verify: `bash -n` not applicable (md); `sed` placeholder render dry-run on tmpl produces valid-looking conf (manual).
- [ ] **Step 6:** Commit `feat(server): proxy auto-detect (nginx/traefik) + cloudflare dns skill`.

---

### Task 7: azzist orchestrator skill

**Files:**
- Create: `skills/azzist/SKILL.md`

- [ ] **Step 1:** Write `SKILL.md`: entry skill. Description triggers on "azzist", "deploy e2e", "ship landing page". Body: detect config presence → run init if absent; then scaffold → deploy → server in order, pausing for user confirm before the remote/destructive deploy step. Reference each sub-skill by name. Embed stack conventions table (nuxt/go/gofiber/python/postgres/redis).
- [ ] **Step 2:** Add the E2E verification checklist from spec (curl https://domain == 200).
- [ ] **Step 3:** Verify frontmatter.
- [ ] **Step 4:** Commit `feat(azzist): orchestrator skill driving full e2e flow`.

---

### Task 8: README + install/verify docs

**Files:**
- Modify: `README.md`

- [ ] **Step 1:** Write README: what it is, stack conventions, install (`/plugin marketplace add <owner>/azzist-skills` → `/plugin install azzist`), config split + secret safety, usage walkthrough (landing page E2E), isolation guarantees (traefik untouched).
- [ ] **Step 2:** Verify links/commands accurate vs actual skill names.
- [ ] **Step 3:** Commit `docs: readme with install + e2e walkthrough`.

---

## Self-Review

- **Spec coverage:** distribution (T1), config split+security (T2), scripts/cf/ssh (T3), nuxt scaffold+docker (T4), isolated deploy (T5), proxy auto-detect+traefik non-interference+DNS+TLS (T6), orchestrator+conventions (T7), install docs (T8). All spec sections mapped.
- **Placeholders:** none — deferred items (image transfer, certbot) resolved: image transfer = `docker save|load` (T5), certbot in nginx path (T6).
- **Naming consistency:** network `azzist_<name>`, containers `azzist_<name>_app`, vhost `conf.d/azzist_<name>.conf`, scripts `azzist_ssh`/`azzist_scp` — consistent across T3/T5/T6.
