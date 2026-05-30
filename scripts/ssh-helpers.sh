#!/usr/bin/env bash
# azzist ssh helpers — source this file, then use azzist_ssh / azzist_scp.
#
# Auth is driven by env vars exported by the caller (read from azzist.local.yaml):
#   AZZIST_SSH_AUTH   ssh_config | key | password
#   AZZIST_SSH_HOST   server host/ip            (key/password modes)
#   AZZIST_SSH_USER   ssh user                  (key/password modes)
#   AZZIST_SSH_ALIAS  ~/.ssh/config Host alias  (ssh_config mode)
#   AZZIST_SSH_KEY    private key path          (key mode)
#   AZZIST_SSH_PASS   password                  (password mode, needs sshpass)
#
# Never echo AZZIST_SSH_PASS. All target args are passed positionally (no eval).

set -euo pipefail

_azzist_ssh_target() {
  case "${AZZIST_SSH_AUTH:?set AZZIST_SSH_AUTH}" in
    ssh_config) printf '%s' "${AZZIST_SSH_ALIAS:?set AZZIST_SSH_ALIAS}" ;;
    key|password) printf '%s@%s' "${AZZIST_SSH_USER:?set AZZIST_SSH_USER}" "${AZZIST_SSH_HOST:?set AZZIST_SSH_HOST}" ;;
    *) echo "azzist: unknown AZZIST_SSH_AUTH=$AZZIST_SSH_AUTH" >&2; return 2 ;;
  esac
}

azzist_ssh() {
  local target; target="$(_azzist_ssh_target)"
  case "$AZZIST_SSH_AUTH" in
    ssh_config) ssh -o BatchMode=yes "$target" "$@" ;;
    key)        ssh -o BatchMode=yes -i "${AZZIST_SSH_KEY:?set AZZIST_SSH_KEY}" "$target" "$@" ;;
    password)
      command -v sshpass >/dev/null || { echo "azzist: password auth needs sshpass" >&2; return 3; }
      sshpass -p "${AZZIST_SSH_PASS:?set AZZIST_SSH_PASS}" ssh -o StrictHostKeyChecking=accept-new "$target" "$@" ;;
  esac
}

# azzist_scp <local_path> <remote_path>
azzist_scp() {
  local target; target="$(_azzist_ssh_target)"
  local src="$1" dst="$2"
  case "$AZZIST_SSH_AUTH" in
    ssh_config) scp "$src" "$target:$dst" ;;
    key)        scp -i "${AZZIST_SSH_KEY:?set AZZIST_SSH_KEY}" "$src" "$target:$dst" ;;
    password)
      command -v sshpass >/dev/null || { echo "azzist: password auth needs sshpass" >&2; return 3; }
      sshpass -p "${AZZIST_SSH_PASS:?set AZZIST_SSH_PASS}" scp -o StrictHostKeyChecking=accept-new "$src" "$target:$dst" ;;
  esac
}
