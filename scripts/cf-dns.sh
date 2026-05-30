#!/usr/bin/env bash
# Idempotently upsert a Cloudflare A record (proxied) pointing a name at an IP.
# Usage: cf-dns.sh <zone_id> <api_token> <record_name> <ip> [proxied]
#   proxied: true|false (default true)
# Requires: curl, jq. Does not print the token.

set -euo pipefail

zone="${1:?zone_id required}"
token="${2:?api_token required}"
name="${3:?record_name required}"
ip="${4:?ip required}"
proxied="${5:-true}"

api="https://api.cloudflare.com/client/v4/zones/${zone}/dns_records"
auth=(-H "Authorization: Bearer ${token}" -H "Content-Type: application/json")

# Look up an existing A record by exact name.
rec_id="$(curl -sf -G "$api" "${auth[@]}" \
  --data-urlencode "type=A" \
  --data-urlencode "name=${name}" \
  | jq -r '.result[0].id // empty')"

body="$(jq -nc --arg name "$name" --arg ip "$ip" --argjson proxied "$proxied" \
  '{type:"A", name:$name, content:$ip, ttl:1, proxied:$proxied}')"

if [[ -n "$rec_id" ]]; then
  curl -sf -X PUT "${api}/${rec_id}" "${auth[@]}" --data "$body" \
    | jq -e '.success' >/dev/null && echo "updated A ${name} -> ${ip}"
else
  curl -sf -X POST "$api" "${auth[@]}" --data "$body" \
    | jq -e '.success' >/dev/null && echo "created A ${name} -> ${ip}"
fi
