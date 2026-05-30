#!/usr/bin/env bash
# Detect the reverse proxy already present on the remote server, without changing anything.
# Echoes one of: traefik | nginx | none
# Usage: source ssh-helpers.sh first (provides azzist_ssh), then: detect-proxy.sh
#
# Priority:
#   1. A running Traefik container  -> "traefik"  (we will integrate via labels, no edits)
#   2. nginx present on the host     -> "nginx"   (we will add ONE isolated vhost)
#   3. neither                        -> "none"    (caller installs nginx)

set -euo pipefail

# 1. Traefik container running?
if azzist_ssh 'sh -c "docker ps --format '\''{{.Image}}'\'' 2>/dev/null"' \
     | grep -qiE '(^|/)traefik(:|$)'; then
  echo traefik
  exit 0
fi

# 2. Host nginx installed?
if azzist_ssh 'sh -c "command -v nginx >/dev/null 2>&1"'; then
  echo nginx
  exit 0
fi

echo none
