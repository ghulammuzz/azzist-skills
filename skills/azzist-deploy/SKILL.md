---
name: azzist-deploy
description: >
  Build the project's Docker image, smoke-test it locally, then ship it to the target server
  over SSH and run it in an ISOLATED Docker network on a free or assigned port. Use when the
  user wants to deploy an azzist project to a server, says "azzist deploy", or after a working
  local scaffold. Strictly avoids touching any existing container, network, or service.
---

# azzist-deploy

Build, ship, and run the container with hard isolation. Read config from `azzist.yaml`
(public) and `azzist.local.yaml` (secrets). Let `<name>` = `project.name`.

## Isolation guardrails (non-negotiable)

- Only create/modify resources prefixed `azzist_<name>`:
  network `azzist_<name>`, container `azzist_<name>_app` (and `_db`, `_cache` if enabled).
- NEVER `stop`/`rm`/`restart`/reconfigure containers, networks, or volumes you did not create.
- NEVER edit existing daemon, proxy, or compose configs. If something unexpected exists,
  stop and ask the user — do not work around it destructively.

## Transfer strategy (read `deploy.transfer` from azzist.yaml)

- **git** (default): the server pulls the repo and builds the image remotely. Preferred —
  no large image upload, reproducible, easy redeploys (`git pull` + rebuild).
- **image**: build locally, smoke-test, then `docker save | docker load` over SSH. Use when
  the server cannot reach the git host or the repo is not pushed.

`deploy.repo` + `deploy.branch` (azzist.yaml) define the source for git mode. Server-side
git credentials are described in `git.auth` (azzist.local.yaml): `deploy_key` (a read-only
key already on the server), `ssh_agent` (forward your local agent), or `token` (HTTPS PAT).

## Steps

1. **Prepare SSH.** Read the server entry (`deploy.server` -> `servers.<server>` in local).
   Export `AZZIST_SSH_AUTH`/`AZZIST_SSH_HOST`/`AZZIST_SSH_USER`/`AZZIST_SSH_ALIAS`/`AZZIST_SSH_KEY`
   as needed and `source ${CLAUDE_PLUGIN_ROOT}/scripts/ssh-helpers.sh`. For `ssh_agent` git
   auth, connect with agent forwarding (`ssh -A`).

1a. **Survey the server BEFORE doing anything.** Always inspect what's already on the box so we
    don't collide or duplicate:
    - **Reverse proxy present?** `bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-proxy.sh` ->
      `traefik` | `nginx` | `none`. If one exists, REUSE it later in azzist-server (do not
      install another). If `none`, ASK the user before installing nginx — never silently add
      a new proxy.
    - **Port conflicts.** Whether `deploy.port: auto` or a fixed number, always check the
      target port is actually free on the server before binding. For `auto`, scan and pick a
      free one (see step 6). For a fixed port, if it is already in use, STOP and ask the user
      whether to pick another or evict (we never evict). Use `azzist_ssh 'ss -tlnH | awk "{print \$4}" | grep -E ":<port>\$"'`.
    - Record both findings; they drive steps 6 (port) and the handoff to azzist-server (proxy).

2. **PREFLIGHT — verify the server can pull the (private) repo.** Do this FIRST, before any
   build, so failures are cheap. Skip only in `image` mode.
   ```
   azzist_ssh 'git ls-remote <deploy.repo> >/dev/null 2>&1 && echo REPO_OK || echo REPO_FAIL'
   ```
   - For `token` (HTTPS): test with the credentialed URL, never echoing the token:
     `azzist_ssh 'git ls-remote https://x-access-token:<token>@github.com/<owner>/<repo>.git >/dev/null 2>&1 && echo REPO_OK || echo REPO_FAIL'`
   - If `REPO_FAIL`: STOP and tell the user exactly how to grant access — add a read-only
     **deploy key** to the repo for the server's SSH key
     (`azzist_ssh 'cat ~/.ssh/id_*.pub'`), or provide a PAT, or use `ssh_agent` forwarding.
     Do not proceed until preflight returns `REPO_OK`.
   - Also confirm `git` exists on the server: `azzist_ssh 'command -v git'` (install if missing).

3. **Ensure remote Docker.** `azzist_ssh 'command -v docker'`. If missing, install Docker via
   the official convenience script (`curl -fsSL https://get.docker.com | sh`) — this adds
   Docker only; it does not alter existing services. Confirm with the user before installing.

3a. **Validate the Dockerfile before any build.** A broken Dockerfile wastes minutes of
    server time — catch it locally first.
    - Confirm `Dockerfile` exists at the build context the build command will use.
    - Lint with `docker build --check .` if available (BuildKit), else a local
      `docker build --target <stage> .` dry-run on the cheap stages.
    - Required contract: image must `EXPOSE` a port AND respond on `/healthz` (liveness)
      and `/readyz` (readiness). If the project's framework doesn't have these, add minimal
      handlers before deploy (Nuxt: a Nitro route handler; Go: a `/healthz` mux entry).
    - Locally run the built image and probe both endpoints:
      ```
      docker run -d --rm --name azzist_<name>_validate -p 13000:3000 azzist_<name>_app:latest
      curl -fsS http://localhost:13000/healthz && curl -fsS http://localhost:13000/readyz
      docker stop azzist_<name>_validate
      ```
      If either probe fails, STOP — do not ship a container that can't report health.

4. **Build + ship (branch on transfer mode).**

   **git mode:** build on the server from a fresh checkout.
   ```
   azzist_ssh 'mkdir -p ~/azzist/<name>'
   # clone once, then pull on redeploys:
   azzist_ssh 'test -d ~/azzist/<name>/.git \
     && git -C ~/azzist/<name> fetch --depth 1 origin <branch> && git -C ~/azzist/<name> reset --hard origin/<branch> \
     || git clone --depth 1 -b <branch> <deploy.repo> ~/azzist/<name>'
   azzist_ssh 'cd ~/azzist/<name> && docker build -t azzist_<name>_app:latest .'
   ```
   (token auth: use the credentialed HTTPS URL for clone/fetch; never print the token.)

   **image mode:** build + smoke-test locally, then transfer the image.
   ```
   docker build -t azzist_<name>_app:latest .
   docker run -d --rm --name azzist_<name>_smoke -p 3000:3000 azzist_<name>_app:latest
   curl -fsS http://localhost:3000 >/dev/null && docker stop azzist_<name>_smoke
   docker save azzist_<name>_app:latest | gzip | azzist_ssh 'gunzip | docker load'
   ```

5. **Isolated network.** Create only if absent:
   `azzist_ssh 'docker network inspect azzist_<name> >/dev/null 2>&1 || docker network create azzist_<name>'`
6. **Resolve port.** If `deploy.port: auto`, `source scripts/ssh-helpers.sh` then
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/free-port.sh` to get a free host port. Else use the
   fixed number. Record it as `<port>` for the server step.
7. **Run container.** Replace any prior instance of OUR app only:
   ```
   azzist_ssh 'docker rm -f azzist_<name>_app 2>/dev/null || true'
   azzist_ssh 'docker run -d --name azzist_<name>_app \
     --network azzist_<name> \
     -p 127.0.0.1:<port>:3000 \
     --restart unless-stopped \
     azzist_<name>_app:latest'
   ```
   Binding to `127.0.0.1:<port>` keeps the app private until the proxy fronts it.
8. **Verify on server.** Probe BOTH endpoints (not just root) to confirm the container is
   actually serving and ready:
   ```
   azzist_ssh 'curl -fsS http://127.0.0.1:<port>/healthz >/dev/null && echo health_ok'
   azzist_ssh 'curl -fsS http://127.0.0.1:<port>/readyz  >/dev/null && echo ready_ok'
   ```
   Both must pass before handoff.

8a. **Pre-check the target domain.** Before handing off to azzist-server, see whether
    `<domain>` already resolves and where it points:
    `dig +short <domain>` (locally) and `curl -sSI http://<domain>` (best-effort).
    - If it already resolves to a DIFFERENT IP than this server, WARN the user — the
      Cloudflare upsert in azzist-server will replace it. Confirm before proceeding.
    - If it resolves to this server already, note it — we just need to ensure proxy + TLS.
    - If it doesn't resolve yet, fine — azzist-server will create the record.

9. Hand `<port>`, the running container, the detected proxy (from step 1a), and the
   domain pre-check result to **azzist-server** for proxy + DNS + TLS + final reachability.

## Optional: database / cache (if enabled in azzist.yaml)

- `database: postgres` -> run `postgres:16-alpine` as `azzist_<name>_db` on network
  `azzist_<name>` with a named volume `azzist_<name>_pgdata`. Not published to host.
- `cache: redis` -> run `redis:7-alpine` as `azzist_<name>_cache` on the same network.
- App reaches them by container name over the private network.

## Output

Report the image built, smoke-test result, the chosen `<port>`, and remote verification.
