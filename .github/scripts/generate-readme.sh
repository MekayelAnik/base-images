#!/usr/bin/env bash
set -euo pipefail

# Inputs from environment
RAW_IMAGES="${RAW_IMAGES:?RAW_IMAGES is required}"
GHCR_OWNER_RAW="${GHCR_OWNER_RAW:?GHCR_OWNER_RAW is required}"
REPO_FULL="${REPO_FULL:?REPO_FULL is required}"
STATUS_DIR="${STATUS_DIR:-}"

OWNER=$(echo "$GHCR_OWNER_RAW" | tr '[:upper:]' '[:lower:]')
NOW=$(date -u '+%Y-%m-%d %H:%M UTC')

# Hardcoded fallback — only used if detection (USED_BY_FILE) returns nothing for an image.
declare -A USED_BY_FALLBACK=(
  ["node:current-alpine"]="context7-mcp-docker"
  ["node:22-slim"]="gitnexus-docker"
  ["node:22-trixie-slim"]="gitnexus-docker"
  ["node:alpine"]="MCP docker repos (time, fetch, brave, etc.)"
  ["golang:1.26-alpine"]="db-MCP-server-docker"
  ["alpine:latest"]="nfs-server, samba-server, proftpd, db-MCP"
  ["python:3-slim"]="codegraphcontext-mcp-docker"
  ["debian:bookworm-slim"]="ispyagentdvr"
  ["debian:trixie-slim"]="ispyagentdvr, vllm-cpu, gitnexus-docker"
  ["debian:stable-slim"]="ispyagentdvr"
)

# Detected Used By from scanning the owner's public repos (optional).
declare -A USED_BY_DETECTED=()
if [[ -n "${USED_BY_FILE:-}" && -f "${USED_BY_FILE}" ]]; then
  while IFS=$'\t' read -r img repos; do
    [[ -z "${img:-}" || -z "${repos:-}" ]] && continue
    USED_BY_DETECTED["$img"]="$repos"
  done < "$USED_BY_FILE"
fi

# Parse existing README to preserve prior "Last Updated" values.
# New format row has 7 pipes: | `img` | `target` | archs | used | status | last_updated |
declare -A PRIOR_UPDATED=()
if [[ -f README.md ]]; then
  while IFS= read -r line; do
    [[ "$line" =~ ^\|[[:space:]]*\`([^\`]+)\`[[:space:]]*\| ]] || continue
    IMG_KEY="${BASH_REMATCH[1]}"
    NPIPES=$(awk -F'|' '{print NF-1}' <<< "$line")
    [[ "$NPIPES" -ge 7 ]] || continue
    LAST=$(awk -F'|' '{v=$7; gsub(/^[[:space:]]+|[[:space:]]+$/,"",v); print v}' <<< "$line")
    PRIOR_UPDATED["$IMG_KEY"]="$LAST"
  done < README.md
fi

# Load per-image run status (mirrored | skipped | unknown) from artifact dir
declare -A RUN_STATUS=()
if [[ -n "$STATUS_DIR" && -d "$STATUS_DIR" ]]; then
  shopt -s nullglob
  for f in "$STATUS_DIR"/*.txt; do
    IFS='|' read -r img st < "$f" || continue
    [[ -n "${img:-}" ]] || continue
    RUN_STATUS["$img"]="${st:-unknown}"
  done
  shopt -u nullglob
fi

# Parse image list
IMAGES=$(echo "$RAW_IMAGES" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | sed '/^$/d' | sort -u)

# Build table rows
TABLE_ROWS=""
while IFS= read -r IMG; do
  [[ -z "$IMG" ]] && continue
  TARGET="ghcr.io/${OWNER}/base-images/${IMG}"

  # Query architectures — anchor on "Platform:" label
  ARCHS=""
  ARCHS=$(docker buildx imagetools inspect "$TARGET" 2>/dev/null \
    | awk '/^[[:space:]]*Platform:[[:space:]]/ {print $2}' \
    | grep -E '^linux/' \
    | grep -vE '/unknown$|^linux/unknown' \
    | sort -u | paste -sd ', ' -) || true
  [[ -z "$ARCHS" ]] && ARCHS="N/A"

  # Determine status
  if docker buildx imagetools inspect "$TARGET" &>/dev/null; then
    STATUS="Mirrored"
  else
    STATUS="Not found"
  fi

  # Prefer auto-detected, fall back to hardcoded map, then em-dash.
  USED="${USED_BY_DETECTED[$IMG]:-}"
  [[ -z "$USED" ]] && USED="${USED_BY_FALLBACK[$IMG]:-}"
  [[ -z "$USED" ]] && USED="—"

  # Determine Last Updated:
  #   mirrored this run -> NOW
  #   else preserve prior value from README
  #   else baseline: NOW if image exists in registry, else "—"
  PRIOR="${PRIOR_UPDATED[$IMG]:-}"
  THIS_RUN="${RUN_STATUS[$IMG]:-}"
  if [[ "$THIS_RUN" == "mirrored" ]]; then
    LAST_UPDATED="$NOW"
  elif [[ -n "$PRIOR" && "$PRIOR" != "—" ]]; then
    LAST_UPDATED="$PRIOR"
  elif [[ "$STATUS" == "Mirrored" ]]; then
    LAST_UPDATED="$NOW"
  else
    LAST_UPDATED="—"
  fi

  TABLE_ROWS+="| \`${IMG}\` | \`${TARGET}\` | ${ARCHS} | ${USED} | ${STATUS} | ${LAST_UPDATED} |"$'\n'
done <<< "$IMAGES"

# Write README (no global "Last synced" — each row tracks its own update time)
cat > README.md <<EOF
# Base Images Mirror

[![Mirror Base Images to GHCR](https://github.com/${REPO_FULL}/actions/workflows/mirror-base-images.yml/badge.svg)](https://github.com/${REPO_FULL}/actions/workflows/mirror-base-images.yml)

Centralized Docker base image mirror from Docker Hub to GitHub Container Registry (GHCR).

## Purpose

Avoids Docker Hub pull rate limits by mirroring base images to GHCR, which has unlimited pulls with \`GITHUB_TOKEN\` in GitHub Actions.

## Mirrored Images

| Source (Docker Hub) | GHCR Mirror | Architectures | Used By | Status | Last Updated |
|:-------------------:|:-----------:|:-------------:|:-------:|:------:|:------------:|
${TABLE_ROWS}
## Adding / Removing Images

1. Go to **Settings > Variables > Actions** in this repo
2. Edit the \`BASE_IMAGES\` variable (comma-separated list)
3. Trigger the workflow — no code changes needed

## Trigger

- **cron-job.org**: POST to \`https://api.github.com/repos/${REPO_FULL}/dispatches\` with body \`{"event_type": "mirror-base-images"}\`
- **Manual**: Actions > Mirror Base Images to GHCR > Run workflow

## Usage in Other Repos

Set \`BASE_IMAGE_DEFAULT\` variable in your repo:

\`\`\`
ghcr.io/${OWNER}/base-images/node:22-slim
\`\`\`

---

*This README is auto-generated by the [mirror workflow](https://github.com/${REPO_FULL}/actions/workflows/mirror-base-images.yml). Do not edit manually.*
EOF

echo "README.md generated successfully"
