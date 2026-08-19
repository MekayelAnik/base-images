#!/usr/bin/env bash
# Mirror every configured base image from Docker Hub to GHCR.
#
# This runs as ONE job looping the images rather than a job-per-image matrix.
# `docker buildx imagetools create` is a registry-side copy: it moves no layers
# through the runner, so a dedicated runner per image bought nothing while
# costing ~18x the job starts (and ~18x the action tarball downloads, which is
# how the fleet hit codeload 429s).
#
# Inputs from environment:
#   RAW_IMAGES  comma-separated image list (e.g. "alpine:latest, python:3-slim")
#   GHCR_OWNER  repository owner; lowercased for the registry path
#   STATUS_DIR  directory to write per-image "IMAGE|STATUS|TS" files into,
#               consumed by generate-readme.sh
#   FORCE       "true" to re-mirror even when digests already match
#
# Exit status is 0 only if every image succeeded. One image failing must not
# stop the others -- that is what the matrix's `fail-fast: false` used to do --
# so failures are collected and reported at the end.
set -uo pipefail

RAW_IMAGES="${RAW_IMAGES:?RAW_IMAGES is required}"
GHCR_OWNER="${GHCR_OWNER:?GHCR_OWNER is required}"
STATUS_DIR="${STATUS_DIR:-status-out}"
FORCE="${FORCE:-false}"

OWNER=$(echo "$GHCR_OWNER" | tr '[:upper:]' '[:lower:]')
mkdir -p "$STATUS_DIR"

# Transient HTTP/2 stream errors and registry 5xx frequently break a single
# copy. Exponential backoff over 5 attempts.
mirror_with_retry() {
  local src="$1" tgt="$2"
  local attempts=5 delay=5 attempt
  for attempt in $(seq 1 "$attempts"); do
    if docker buildx imagetools create -t "$tgt" "$src"; then
      [[ "$attempt" -gt 1 ]] && echo "  succeeded on attempt ${attempt}"
      return 0
    fi
    if [[ "$attempt" -eq "$attempts" ]]; then
      echo "::error::mirror failed after ${attempts} attempts: $src -> $tgt"
      return 1
    fi
    echo "::warning::mirror attempt ${attempt} failed -- retrying in ${delay}s"
    sleep "$delay"
    delay=$(( delay * 2 ))
  done
}

digest_of() {
  docker buildx imagetools inspect "$1" --raw 2>/dev/null | sha256sum | awk '{print "sha256:"$1}'
}

FAILED=0
TOTAL=0
MIRRORED=0
SKIPPED=0

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "| | Image | Status |"
    echo "|---|---|---|"
  } >> "$GITHUB_STEP_SUMMARY"
fi

while IFS= read -r IMAGE; do
  [[ -n "$IMAGE" ]] || continue
  TOTAL=$(( TOTAL + 1 ))
  echo "::group::$IMAGE"

  # Namespaced images (e.g. moby/buildkit) use docker.io/<image> directly;
  # official library images (e.g. node, alpine) use docker.io/library/<image>
  if [[ "$IMAGE" == */* ]]; then
    SOURCE="docker.io/${IMAGE}"
  else
    SOURCE="docker.io/library/${IMAGE}"
  fi
  TARGET="ghcr.io/${OWNER}/base-images/${IMAGE}"

  STATUS="unknown"
  REASON=""
  TS=""

  SOURCE_DIGEST=$(digest_of "$SOURCE") || SOURCE_DIGEST=""

  if [[ -z "$SOURCE_DIGEST" ]]; then
    echo "::warning::Could not inspect source $SOURCE -- mirroring unconditionally"
    if mirror_with_retry "$SOURCE" "$TARGET"; then
      STATUS="mirrored"; REASON="source-inspect-failed"; TS=$(date -u '+%Y-%m-%d %H:%M UTC')
    else
      STATUS="failed"; REASON="source-inspect-failed"; FAILED=1
    fi
  else
    TARGET_DIGEST=$(digest_of "$TARGET") || TARGET_DIGEST=""
    echo "Source digest: ${SOURCE_DIGEST:0:26}..."
    if [[ -n "$TARGET_DIGEST" ]]; then
      echo "Target digest: ${TARGET_DIGEST:0:26}..."
    else
      echo "Target digest: <not found>"
    fi

    if [[ "$FORCE" != "true" && -n "$TARGET_DIGEST" && "$SOURCE_DIGEST" == "$TARGET_DIGEST" ]]; then
      echo "Already up-to-date -- skipping mirror"
      STATUS="skipped"; REASON="digest-match"
    else
      REASON="new-image"
      [[ "$FORCE" == "true" ]] && REASON="force-mirror"
      [[ -n "$TARGET_DIGEST" && "$SOURCE_DIGEST" != "$TARGET_DIGEST" ]] && REASON="digest-changed"
      echo "Mirroring $SOURCE -> $TARGET (reason: $REASON)"
      if mirror_with_retry "$SOURCE" "$TARGET"; then
        TS=$(date -u '+%Y-%m-%d %H:%M UTC')
        echo "Done: $TARGET at $TS"
        STATUS="mirrored"
      else
        STATUS="failed"; FAILED=1
      fi
    fi
  fi

  case "$STATUS" in
    skipped)  ICON="⏭️"; DESC="Already up-to-date"; SKIPPED=$(( SKIPPED + 1 )) ;;
    mirrored) ICON="✅"; DESC="Mirrored ($REASON)"; MIRRORED=$(( MIRRORED + 1 )) ;;
    failed)   ICON="❌"; DESC="Failed ($REASON)" ;;
    *)        ICON="❌"; DESC="Unknown status" ;;
  esac
  [[ -n "${GITHUB_STEP_SUMMARY:-}" ]] && echo "| $ICON | \`$IMAGE\` | $DESC |" >> "$GITHUB_STEP_SUMMARY"

  # Sanitize image name for filename: / and : -> __
  SAFE=$(echo "$IMAGE" | sed 's#[/:]#__#g')
  printf '%s|%s|%s\n' "$IMAGE" "$STATUS" "$TS" > "${STATUS_DIR}/${SAFE}.txt"

  echo "::endgroup::"
done < <(echo "$RAW_IMAGES" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | sed '/^$/d' | sort -u)

echo "Images: $TOTAL total, $MIRRORED mirrored, $SKIPPED up-to-date, failures: $FAILED"

if [[ "$TOTAL" -eq 0 ]]; then
  echo "::error::No images parsed from RAW_IMAGES"
  exit 1
fi

exit "$FAILED"
