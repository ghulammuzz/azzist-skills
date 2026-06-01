---
name: azzist-server
description: >
  Expose a deployed azzist container publicly: detect the server's existing reverse proxy
  (Traefik container, host nginx, or none) and wire the app non-invasively, then upsert the
  Cloudflare DNS record and provision TLS. Use after azzist-deploy, when the user says
  "azzist server", "attach domain", or "make it public". Never disturbs existing proxies/services.
---

# azzist-server

Front the running container at `127.0.0.1:<port>` with a reverse proxy and a public domain.
Inputs: `<name>` = `project.name`, `<domain>`, `<port>` (from azzist-deploy), `deploy.proxy`,
and `cloudflare` secrets from `azzist.local.yaml`. Source ssh helpers first:
`source ${CLAUDE_PLUGIN_ROOT}/scripts/ssh-helpers.sh` (with AZZIST_SSH_* exported).

## Dual purpose: deploy wiring AND infra/server debugging

This skill is used in two modes:

1. **Wire mode (post-deploy):** the steps below — proxy + DNS + TLS + reachability check.
2. **Debug mode (anytime):** the same SSH helpers, proxy detector, port scanner, and DNS
   helper double as an infra-layer debugging surface. When the user reports "site is down",
   "502 / 504 / SSL error", "DNS not resolving", "proxy misbehaving", or "container not
   reachable from outside", run this skill in debug mode:
   - `bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-proxy.sh` — what proxy is actually running?
   - `azzist_ssh 'docker ps --filter name=azzist_<name>'` — is OUR container up?
   - `azzist_ssh 'curl -fsS http://127.0.0.1:<port>/healthz'` — is the app healthy on the loopback?
   - `azzist_ssh 'ss -tlnH | grep <port>'` — is the port bound?
   - `azzist_ssh 'sudo nginx -T 2>/dev/null | grep -A5 azzist_<name>'` — is OUR vhost present?
   - `azzist_ssh 'docker logs --tail=200 traefik'` (or our app) — what does the proxy say?
   - `dig +short <domain>` and `curl -sSIv https://<domain>` — DNS + TLS reachable?
   - Cloudflare API GET via `cf-dns.sh`-style call to inspect the current record.
   Diagnose at the boundary that broke (container → proxy → DNS → TLS) and propose the
   minimal fix. Same isolation rule applies: do not touch resources outside `azzist_<name>*`.

## 1. Decide proxy strategy

If `deploy.proxy: auto`, detect:
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-proxy.sh` -> `traefik` | `nginx` | `none`.
If `deploy.proxy` is `nginx` or `traefik`, honor it (still verify it actually exists).

### Strategy: traefik (existing Traefik container — DO NOT reconfigure it)

Integrate purely via Docker labels and Traefik's network. No file or Traefik-config edits.

1. Find Traefik's docker network:
   `azzist_ssh "docker inspect \$(docker ps -qf ancestor=traefik | head -n1) --format '{{range \$k,\$v := .NetworkSettings.Networks}}{{\$k}}{{end}}'"`
   (or ask the user which network Traefik watches). Call it `<traefiknet>`.
2. Connect our app to that network (additive, non-destructive):
   `azzist_ssh 'docker network connect <traefiknet> azzist_<name>_app 2>/dev/null || true'`
3. Re-run our app container WITH labels (replace OUR container only). Keep it on its own
   `azzist_<name>` network too. Drop the host port publish — Traefik routes internally:
   ```
   azzist_ssh 'docker rm -f azzist_<name>_app'
   azzist_ssh 'docker run -d --name azzist_<name>_app \
     --network azzist_<name> \
     --restart unless-stopped \
     --label traefik.enable=true \
     --label "traefik.http.routers.azzist_<name>.rule=Host(\`<domain>\`)" \
     --label traefik.http.services.azzist_<name>.loadbalancer.server.port=3000 \
     azzist_<name>_app:latest'
   azzist_ssh 'docker network connect <traefiknet> azzist_<name>_app'
   ```
4. TLS: rely on Traefik's existing certresolver. If you know its name, add
   `--label traefik.http.routers.azzist_<name>.tls.certresolver=<resolver>`. Do NOT create or
   edit Traefik's resolver config. If unknown, ask the user; otherwise leave TLS to Traefik defaults.

### Strategy: nginx (host nginx present)

Write exactly ONE isolated vhost file; never edit existing config.

1. Render template:
   `sed -e 's/__DOMAIN__/<domain>/g' -e 's/__PORT__/<port>/g' -e 's/__NAME__/<name>/g' \
     ${CLAUDE_PLUGIN_ROOT}/templates/nginx.vhost.conf.tmpl > /tmp/azzist_<name>.conf`
2. Copy to server and place it: `azzist_scp /tmp/azzist_<name>.conf /tmp/azzist_<name>.conf`
   then `azzist_ssh 'sudo mv /tmp/azzist_<name>.conf /etc/nginx/conf.d/azzist_<name>.conf'`.
3. Validate + reload (fails safe if our file is bad):
   `azzist_ssh 'sudo nginx -t && sudo systemctl reload nginx'`.
4. TLS via certbot (after DNS in step 2 propagates):
   `azzist_ssh 'sudo certbot --nginx -d <domain> --non-interactive --agree-tos -m <email> --redirect'`.
   Install certbot first only if absent.

### Strategy: none (no proxy installed)

Confirm with the user, then install nginx (`apt-get install -y nginx` / distro equiv) and
follow the **nginx** strategy. Installing nginx adds a service; it does not alter others.

## 2. Cloudflare DNS

Upsert the A record domain -> server public IP:
```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/cf-dns.sh "<zone_id>" "<api_token>" "<domain>" "<server_ip>" true
```
`<server_ip>` = the server's public IP (from `servers.<server>.host` if public, else ask).

## 3. Verify public reachability

`curl -fsS -I https://<domain>` should return `200`/`301`. Allow a minute for DNS + cert.
Report the final status code and the public URL.

## Output

State: detected proxy strategy, what was wired (vhost file path or Traefik labels), the
Cloudflare record result, and the final `curl https://<domain>` status.
