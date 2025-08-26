#!/bin/sh
set -euo pipefail

# Read entire JSON payload from stdin:
INPUT="$(cat || true)"

# Secrets from env first; otherwise from stdin.params (avoid leaking in logs/state)
do_access_token="${do_access_token:-}"
if [ -z "${do_access_token}" ]; then
  do_access_token="$(printf '%s' "$INPUT" | jq -r '(.params.do_access_token // .do_access_token // empty)')"
fi

# Non-secrets from env or stdin.params
do_project_id="${do_project_id:-$(printf '%s' "$INPUT" | jq -r '(.params.do_project_id // .do_project_id // empty)')}"
do_tag_name="${do_tag_name:-$(printf '%s' "$INPUT" | jq -r '(.params.do_tag_name // .do_tag_name // empty)')}"

# Validate
[ -n "${do_access_token:-}" ] || { echo "Error: do_access_token missing (env or stdin.params)" >&2; exit 1; }
[ -n "${do_project_id:-}" ]  || { echo "Error: do_project_id missing (env or stdin.params)"  >&2; exit 1; }
[ -n "${do_tag_name:-}" ]    || { echo "Error: do_tag_name missing (env or stdin.params)"    >&2; exit 1; }

label="starthub-tag:${do_tag_name}"
echo "📝 Updating project ${do_project_id} description to include '${label}'..." >&2

# 1) Fetch current project
get_resp="$(
  curl -sS -f -X GET "https://api.digitalocean.com/v2/projects/${do_project_id}" \
    -H "Authorization: Bearer ${do_access_token}" \
    -H "Content-Type: application/json"
)"

current_desc="$(printf '%s' "$get_resp" | jq -r '.project.description // ""')"

# 2) Build new description idempotently
case "$current_desc" in
  *"$label"*) new_desc="$current_desc" ;;
  "")         new_desc="$label" ;;
  *)          new_desc="$current_desc, $label" ;;
esac

# 3) PATCH only if needed
if [ "$new_desc" = "$current_desc" ]; then
  patch_resp="$get_resp"
else
  patch_resp="$(
    curl -sS -f -X PATCH "https://api.digitalocean.com/v2/projects/${do_project_id}" \
      -H "Authorization: Bearer ${do_access_token}" \
      -H "Content-Type: application/json" \
      -d "$(jq -nc --arg d "$new_desc" '{description:$d}')"
  )"
fi

# 4) Verify success
project_id_parsed="$(printf '%s' "$patch_resp" | jq -r '.project.id // empty')"
[ -n "$project_id_parsed" ] || { echo "❌ Failed to update project"; echo "$patch_resp" | jq . >&2; exit 1; }

# 5) ✅ Emit output that matches the manifest exactly
echo "::starthub:state::{\"do_tag_name\":\"${do_tag_name}\"}"

# 6) Human-readable logs to STDERR
{
  echo "✅ Tag ensured in description. Project ID: ${project_id_parsed}"
  echo "Final description:"
  printf '%s\n' "$patch_resp" | jq -r '.project.description // ""'
} >&2
