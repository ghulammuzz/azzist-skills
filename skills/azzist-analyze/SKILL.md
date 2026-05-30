---
name: azzist-analyze
description: >
  Comprehensively identify an EXISTING project so azzist can deploy it: trace every source
  file (excluding dependency/build/VCS folders), detect the stack, build/run commands, ports,
  Dockerfiles, env vars, and database/cache usage, then propose an azzist.yaml. Use when the
  user points azzist at a project that already has code, says "azzist analyze", "deploy this
  existing repo/app", or before deploy when no azzist.yaml exists but source already does.
---

# azzist-analyze

Build an accurate picture of an existing codebase before deploying it. Be thorough: actually
trace the files, do not guess from one marker. The goal is a correct `azzist.yaml` and a
deploy plan that fits what the project really is.

## 1. Inventory every source file (skip dependency/build/VCS dirs)

Excluded directories (never descend into these — they are deps/build/VCS noise):
`node_modules`, `.git`, `.svn`, `.hg`, `.nuxt`, `.output`, `.next`, `.nitro`, `dist`, `build`,
`out`, `coverage`, `.cache`, `vendor` (Go/PHP), `target` (Rust/Java), `__pycache__`,
`.venv`, `venv`, `.mypy_cache`, `.pytest_cache`, `.tox`, `.gradle`, `.idea`, `.vscode`,
`.terraform`, `tmp`, `.DS_Store`.

Get the full file list (fast, respects excludes):
```bash
rg --files \
  --glob '!node_modules' --glob '!.git' --glob '!.nuxt' --glob '!.output' --glob '!.next' \
  --glob '!dist' --glob '!build' --glob '!out' --glob '!coverage' --glob '!vendor' \
  --glob '!target' --glob '!__pycache__' --glob '!.venv' --glob '!venv' --glob '!.cache' \
  --glob '!.gradle' --glob '!.terraform' --glob '!tmp'
```
Fallback if `rg` is absent:
```bash
find . \( -name node_modules -o -name .git -o -name .nuxt -o -name .output -o -name .next \
  -o -name dist -o -name build -o -name out -o -name vendor -o -name target \
  -o -name __pycache__ -o -name .venv -o -name venv -o -name .cache \) -prune -o -type f -print
```
Comprehensive means: walk the WHOLE tree (all subdirs, monorepo packages included), not just
the root. Read the files that matter (below) — do not stop at filename pattern-matching.

## 2. Detect stack from markers (confirm by reading, not just presence)

| Marker file(s)                                   | Stack / signal                         |
|--------------------------------------------------|----------------------------------------|
| `nuxt.config.{ts,js}`                            | Nuxt 3 (web)                           |
| `package.json` w/ `next`                         | Next.js                                |
| `package.json` w/ `vite`+`vue`/`react`           | Vite SPA                               |
| `package.json` (other)                           | Node app — read `scripts`/`main`       |
| `go.mod`                                          | Go — grep for `gofiber/fiber` = worker/API |
| `pyproject.toml` / `requirements.txt` / `Pipfile`| Python — read entrypoint               |
| `Cargo.toml`                                      | Rust                                   |
| `pom.xml` / `build.gradle`                        | Java/JVM                               |
| `composer.json`                                   | PHP                                    |
| `Gemfile`                                          | Ruby                                   |

Read `package.json` `scripts`, `go.mod`, `pyproject.toml`, etc. to get the real build and
run commands — do not assume. For monorepos, identify each deployable app separately.

## 3. Detect deployment-relevant facts (read the files)

- **Existing Docker:** `Dockerfile*`, `docker-compose*.{yml,yaml}`, `.dockerignore`. If a
  Dockerfile exists, prefer it over azzist's template. Read `EXPOSE`, `CMD`/`ENTRYPOINT`,
  and any `ENV PORT`/`NITRO_PORT` to learn the container port.
- **Listening port:** grep source/config for `PORT`, `listen(`, `:3000`, `:8080`, `addr`,
  `app.Listen`, `http.ListenAndServe`, server config. Record the container's internal port.
- **Env requirements:** `.env.example`, `.env.sample`, `config.*`, code reading
  `process.env` / `os.Getenv` / `os.environ`. List required env vars (NOT their secret values).
- **Database / cache:** grep deps + code for `postgres`/`pg`/`pgx`/`sqlx`/`gorm`,
  `redis`/`ioredis`/`go-redis`. Map to azzist `database: postgres` / `cache: redis` if used.
- **Migrations / seed / build steps:** note anything that must run before/at deploy.
- **Static vs server:** SPA build that emits static files vs a long-running server — affects
  whether the container serves or just hosts assets.

## 4. Propose azzist.yaml

From the findings, draft an `azzist.yaml` and show it to the user for confirmation:
```yaml
project:
  name: <derived from repo/dir>
  stack: <nuxt|go|gofiber|python|other-detected>
domain: <ask user>
deploy:
  proxy: auto
  port: auto                 # or the detected internal port if it must be fixed
  server: <ask which server entry>
database: <none|postgres>    # set from detection
cache: <none|redis>          # set from detection
```
Also report: detected internal container port, whether to use the project's existing
Dockerfile or azzist's template, required env vars the user must supply (into
`azzist.local.yaml` or container env), and any build/migration steps.

## 5. Hand off

- If the user confirms, continue: run **azzist-init** (only to create `azzist.local.yaml`
  secrets + ensure gitignore; reuse the proposed `azzist.yaml`), then **azzist-deploy** and
  **azzist-server**. Skip **azzist-scaffold** — the project already exists.

## Output

A structured report: detected stack(s), build/run commands, container port, Docker status,
DB/cache, required env vars, and the proposed `azzist.yaml`. State explicitly what you traced
(how many files / which dirs excluded) so the user can trust the analysis is comprehensive.
