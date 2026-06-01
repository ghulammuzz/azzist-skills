---
name: azzist-init
description: >
  Generate azzist config files for a project: a committed azzist.yaml skeleton and a
  gitignored azzist.local.yaml for secrets (Cloudflare token, SSH credentials). Use when
  the user starts an azzist deployment, says "azzist init", "set up azzist config", or
  before any azzist scaffold/deploy step when no azzist.yaml exists yet.
---

# azzist-init

Create the two-file config split so secrets never land in a public repo.

This skill is **idempotent and only concerns config files** — it creates or updates
`azzist.yaml` + `azzist.local.yaml`, nothing else.

- If **azzist-analyze** ran just before this, REUSE its proposed yaml fields to populate
  `azzist.yaml` (project name, stack, port, db/cache, repo, branch). Don't re-ask for
  things analyze already figured out — just confirm with the user once.
- If `azzist.yaml` already exists AND `azzist.local.yaml` already exists with the expected
  keys filled in, STOP and tell the user: *"already initialized — `azzist.yaml` at <path>
  and `azzist.local.yaml` (gitignored) are in place. Re-run azzist-analyze to refresh
  detection, or edit the files directly."* Don't overwrite them silently.
- If only one of the two exists, create the missing one. If both exist but fields drifted
  (e.g. analyze detected a new stack), offer to UPDATE specific fields rather than
  regenerating from scratch.

## Security first (do this BEFORE writing any secret file)

1. Ensure the project `.gitignore` excludes the secrets file. If `.gitignore` does not
   already contain `azzist.local.yaml`, append these lines:
   ```
   azzist.local.yaml
   **/azzist.local.yaml
   ```
   Verify with `git check-ignore azzist.local.yaml` (should print the path) before
   continuing. If the project is not a git repo, still create `.gitignore` so it is safe
   the moment it becomes one.

## Steps

2. Copy the skeleton to the project root as `azzist.yaml`:
   - Source: `${CLAUDE_PLUGIN_ROOT}/templates/config/azzist.yaml`
   - Fill in what you already know from the conversation (project name, stack, domain).
3. Copy the secrets template to the project root as `azzist.local.yaml`:
   - Source: `${CLAUDE_PLUGIN_ROOT}/templates/config/azzist.local.yaml.example`
   - Do NOT invent secrets. Leave placeholders and ask the user to fill:
     Cloudflare `api_token` + `zone_id`, and per-server `host`, `ssh_user`, `auth` mode.
4. Recommend SSH auth order: `ssh_config` alias > `key` > `password`. Only use `password`
   if the user insists, and warn it needs `sshpass` locally.
5. Confirm to the user:
   - `azzist.yaml` is committed (no secrets).
   - `azzist.local.yaml` is gitignored (holds secrets) — never commit it.

## Output

Report which files were created and exactly which fields the user still needs to fill in
`azzist.local.yaml` before deploy can run.
