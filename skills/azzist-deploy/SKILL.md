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

## Steps

1. **Build locally.** From the project dir: `docker build -t azzist_<name>_app:latest .`
2. **Local smoke test.**
   `docker run -d --rm --name azzist_<name>_smoke -p 3000:3000 azzist_<name>_app:latest`,
   `curl -fsS http://localhost:3000 >/dev/null`, then `docker stop azzist_<name>_smoke`.
   Fix any failure before shipping.
3. **Prepare SSH.** Read the server entry (`deploy.server` -> `servers.<server>` in local).
   Export `AZZIST_SSH_AUTH`/`AZZIST_SSH_HOST`/`AZZIST_SSH_USER`/`AZZIST_SSH_ALIAS`/`AZZIST_SSH_KEY`
   as needed and `source ${CLAUDE_PLUGIN_ROOT}/scripts/ssh-helpers.sh`.
4. **Ensure remote Docker.** `azzist_ssh 'command -v docker'`. If missing, install Docker via
   the official convenience script (`curl -fsSL https://get.docker.com | sh`) — this adds
   Docker only; it does not alter existing services. Confirm with the user before installing.
5. **Transfer image.**
   `docker save azzist_<name>_app:latest | azzist_ssh 'docker load'`
   (gzip the pipe for large images: `docker save ... | gzip | azzist_ssh 'gunzip | docker load'`).
6. **Isolated network.** Create only if absent:
   `azzist_ssh 'docker network inspect azzist_<name> >/dev/null 2>&1 || docker network create azzist_<name>'`
7. **Resolve port.** If `deploy.port: auto`, `source scripts/ssh-helpers.sh` then
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/free-port.sh` to get a free host port. Else use the
   fixed number. Record it as `<port>` for the server step.
8. **Run container.** Replace any prior instance of OUR app only:
   ```
   azzist_ssh 'docker rm -f azzist_<name>_app 2>/dev/null || true'
   azzist_ssh 'docker run -d --name azzist_<name>_app \
     --network azzist_<name> \
     -p 127.0.0.1:<port>:3000 \
     --restart unless-stopped \
     azzist_<name>_app:latest'
   ```
   Binding to `127.0.0.1:<port>` keeps the app private until the proxy fronts it.
9. **Verify on server.** `azzist_ssh 'curl -fsS http://127.0.0.1:<port> >/dev/null && echo up'`.
10. Hand `<port>` and the running container to **azzist-server** for proxy + DNS.

## Optional: database / cache (if enabled in azzist.yaml)

- `database: postgres` -> run `postgres:16-alpine` as `azzist_<name>_db` on network
  `azzist_<name>` with a named volume `azzist_<name>_pgdata`. Not published to host.
- `cache: redis` -> run `redis:7-alpine` as `azzist_<name>_cache` on the same network.
- App reaches them by container name over the private network.

## Output

Report the image built, smoke-test result, the chosen `<port>`, and remote verification.
