#!/usr/bin/env bash
# Scan the owner's public repos for references to ghcr.io/<owner>/base-images/<img>
# and emit a TSV mapping each image tag -> comma-separated list of consuming repos.
#
# Requires: gh CLI authenticated with GITHUB_TOKEN (or PAT in GH_TOKEN).
# Exits 0 even on soft failures so update-readme falls back to the hardcoded map.

set -uo pipefail

OWNER_RAW="${OWNER:?OWNER required (GitHub login of repo owner)}"
OUT="${OUT:-used-by.tsv}"
SEARCH_LIMIT="${SEARCH_LIMIT:-200}"

OWNER_LC=$(echo "$OWNER_RAW" | tr '[:upper:]' '[:lower:]')
: > "$OUT"

if ! command -v gh >/dev/null 2>&1; then
  echo "::warning::gh CLI missing — skipping Used By detection"
  exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "::warning::jq missing — skipping Used By detection"
  exit 0
fi

# Search owner-scoped public code for the base-images namespace.
# Case-insensitive on GH search; OWNER_LC is safe.
QUERY="ghcr.io/${OWNER_LC}/base-images/"
echo "Searching: '${QUERY}' owner=${OWNER_RAW}"

RESULTS=$(gh search code "$QUERY" \
  --owner "$OWNER_RAW" \
  --limit "$SEARCH_LIMIT" \
  --json repository,path \
  2>/dev/null || echo '[]')

COUNT=$(echo "$RESULTS" | jq 'length')
echo "Hits: ${COUNT}"
if [[ "$COUNT" -eq 0 ]]; then
  echo "No hits — leaving ${OUT} empty"
  exit 0
fi

declare -A MAP=()

# De-dupe (repo, path) pairs — gh may return multi-match lines per file.
PAIRS=$(echo "$RESULTS" | jq -r '.[] | [.repository.nameWithOwner, .path] | @tsv' | sort -u)

while IFS=$'\t' read -r REPO PATHF; do
  [[ -z "${REPO:-}" || -z "${PATHF:-}" ]] && continue
  # Skip our own repo and any base-images fork — would be self-referential.
  if [[ "${REPO,,}" == "${OWNER_LC}/base-images" ]]; then
    continue
  fi

  CONTENT=$(gh api "repos/${REPO}/contents/${PATHF}" --jq '.content' 2>/dev/null | base64 -d 2>/dev/null || true)
  [[ -z "$CONTENT" ]] && continue

  REPO_NAME="${REPO##*/}"

  # Extract full image refs after the base-images prefix; stop at quote/space/backslash/newline/#.
  while IFS= read -r IMG; do
    [[ -z "$IMG" ]] && continue
    existing="${MAP[$IMG]:-}"
    if [[ -z "$existing" ]]; then
      MAP["$IMG"]="$REPO_NAME"
    elif [[ ",${existing// /}," != *",${REPO_NAME},"* ]]; then
      MAP["$IMG"]="${existing}, ${REPO_NAME}"
    fi
  done < <(echo "$CONTENT" \
    | grep -oE "ghcr\.io/${OWNER_LC}/base-images/[^[:space:]\"'\\\\\\\$#}]+" \
    | sed "s|ghcr\.io/${OWNER_LC}/base-images/||" \
    | sort -u)
done <<< "$PAIRS"

# --- Optional enrichment: scan repo Actions variables ---
# Catches BASE_IMAGE_DEFAULT-style vars referencing the base-images registry.
# Requires a PAT with actions:read on target repos; default GITHUB_TOKEN is
# scoped to the current repo only and will 403 elsewhere. Fail-soft per repo.
PREFIX="ghcr.io/${OWNER_LC}/base-images/"
REPOS_JSON=$(gh api "users/${OWNER_RAW}/repos?type=owner&per_page=100" --paginate 2>/dev/null || echo '[]')
REPO_LIST=$(echo "$REPOS_JSON" | jq -r '.[]? | select(.archived==false and .fork==false) | .full_name' 2>/dev/null || true)

VAR_HITS=0
while IFS= read -r REPO; do
  [[ -z "$REPO" ]] && continue
  [[ "${REPO,,}" == "${OWNER_LC}/base-images" ]] && continue
  VARS_JSON=$(gh api "repos/${REPO}/actions/variables" --paginate 2>/dev/null || true)
  [[ -z "$VARS_JSON" ]] && continue
  REPO_NAME="${REPO##*/}"
  while IFS= read -r VAL; do
    [[ -z "$VAL" ]] && continue
    IMG="${VAL#${PREFIX}}"
    [[ "$IMG" == "$VAL" ]] && continue
    VAR_HITS=$((VAR_HITS + 1))
    existing="${MAP[$IMG]:-}"
    if [[ -z "$existing" ]]; then
      MAP["$IMG"]="$REPO_NAME"
    elif [[ ",${existing// /}," != *",${REPO_NAME},"* ]]; then
      MAP["$IMG"]="${existing}, ${REPO_NAME}"
    fi
  done < <(echo "$VARS_JSON" | jq -r --arg prefix "$PREFIX" '.variables[]? | select((.value | tostring) | startswith($prefix)) | .value' 2>/dev/null)
done <<< "$REPO_LIST"
echo "Actions variables matches: ${VAR_HITS}"

for img in "${!MAP[@]}"; do
  printf '%s\t%s\n' "$img" "${MAP[$img]}" >> "$OUT"
done

echo "Wrote ${OUT} ($(wc -l < "$OUT") entries):"
cat "$OUT" || true
