#!/usr/bin/env bash
# Find a free host port on the remote server in a range. Echoes first free port.
# Usage: source ssh-helpers.sh first (provides azzist_ssh), then:
#   free-port.sh [start] [end]   (defaults 8000 8999)
#
# Reads listening TCP ports via `ss` (fallback `netstat`) on the remote, then returns
# the first port in [start,end] that is not in use. Read-only; touches nothing.

set -euo pipefail

start="${1:-8000}"
end="${2:-8999}"

# shellcheck disable=SC2016  # remote command runs on server, not locally expanded
used="$(azzist_ssh 'sh -c "ss -tlnH 2>/dev/null || netstat -tlnp 2>/dev/null"' \
  | grep -oE ':[0-9]+ ' | tr -d ': ' | sort -un)"

for ((p=start; p<=end; p++)); do
  if ! grep -qx "$p" <<<"$used"; then
    echo "$p"
    exit 0
  fi
done

echo "azzist: no free port in ${start}-${end}" >&2
exit 1
