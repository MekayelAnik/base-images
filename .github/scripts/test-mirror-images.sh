#!/usr/bin/env bash
# Self-check for mirror-images.sh. Stubs `docker` so nothing touches a real
# registry: the stub records every imagetools invocation and returns canned
# digests driven by the image name.
#
# Covers the behaviours the job-per-image matrix used to provide for free:
# one image failing must not stop the rest, the run must still fail, and
# namespaced images must not get a library/ prefix.
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

# --- docker stub -----------------------------------------------------------
# inspect: SAME_* -> identical digest both sides; DIFF_* -> differing;
#          NOSRC_* -> source inspect fails; anything else -> not found in GHCR.
# create:  BADPUSH_* fails, everything else succeeds.
mkdir -p "$WORK/bin"
cat > "$WORK/bin/docker" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$CALLS"
if [[ "$1" == "buildx" && "$2" == "imagetools" && "$3" == "inspect" ]]; then
  ref=$4
  case "$ref" in
    *NOSRC*)  exit 1 ;;
    *SAME*)   echo "same-content"; exit 0 ;;
    *DIFF*)   if [[ "$ref" == ghcr.io/* ]]; then echo "old-content"; else echo "new-content"; fi; exit 0 ;;
    *BADPUSH*) if [[ "$ref" == ghcr.io/* ]]; then exit 1; fi; echo "x"; exit 0 ;;
    ghcr.io/*) exit 1 ;;
    *)        echo "src"; exit 0 ;;
  esac
fi
if [[ "$1" == "buildx" && "$2" == "imagetools" && "$3" == "create" ]]; then
  [[ "$*" == *BADPUSH* ]] && exit 1
  exit 0
fi
exit 0
STUB
chmod +x "$WORK/bin/docker"
export PATH="$WORK/bin:$PATH"
export CALLS="$WORK/calls.txt"

run_mirror() {
  : > "$CALLS"
  rm -rf "$WORK/status"
  RAW_IMAGES="$1" GHCR_OWNER="MekayelAnik" STATUS_DIR="$WORK/status" FORCE="${2:-false}" \
    GITHUB_STEP_SUMMARY="$WORK/summary.md" \
    bash "$HERE/mirror-images.sh" > "$WORK/out.txt" 2>&1
  echo $?
}
status_of() { cut -d'|' -f2 < "$WORK/status/$1.txt"; }

# --- Case 1: digests match -> skip, no create ------------------------------
echo "== Case 1: up-to-date image =="
rc=$(run_mirror "SAME:latest")
[ "$rc" = 0 ] || fail "expected exit 0, got $rc"
[ "$(status_of SAME__latest)" = "skipped" ] || fail "expected skipped, got $(status_of SAME__latest)"
grep -q "imagetools create" "$CALLS" && fail "create called for an up-to-date image"
echo "  skipped, no push"

# --- Case 2: digests differ -> mirror --------------------------------------
echo "== Case 2: changed upstream =="
rc=$(run_mirror "DIFF:latest")
[ "$rc" = 0 ] || fail "expected exit 0, got $rc"
[ "$(status_of DIFF__latest)" = "mirrored" ] || fail "expected mirrored"
grep -q "imagetools create -t ghcr.io/mekayelanik/base-images/DIFF:latest docker.io/library/DIFF:latest" "$CALLS" \
  || fail "create not called with the expected refs"
echo "  mirrored with library/ prefix"

# --- Case 3: namespaced image keeps its namespace --------------------------
echo "== Case 3: namespaced image =="
rc=$(run_mirror "moby/DIFF:master")
grep -q "docker.io/moby/DIFF:master" "$CALLS" || fail "namespaced source wrong"
grep -q "docker.io/library/moby" "$CALLS" && fail "library/ wrongly prefixed onto a namespaced image"
[ "$(status_of moby__DIFF__master)" = "mirrored" ] || fail "expected mirrored"
echo "  no library/ prefix, filename sanitized"

# --- Case 4: source unreachable -> mirror unconditionally ------------------
echo "== Case 4: source inspect fails =="
rc=$(run_mirror "NOSRC:latest")
[ "$rc" = 0 ] || fail "expected exit 0, got $rc"
[ "$(status_of NOSRC__latest)" = "mirrored" ] || fail "expected unconditional mirror"
echo "  mirrored unconditionally"

# --- Case 5: force re-mirrors an up-to-date image --------------------------
echo "== Case 5: force_mirror =="
rc=$(run_mirror "SAME:latest" true)
[ "$(status_of SAME__latest)" = "mirrored" ] || fail "force did not re-mirror"
grep -q "force-mirror" "$WORK/out.txt" || fail "force reason not logged"
echo "  re-mirrored on force"

# --- Case 6: one failure must not stop the others, run still fails ---------
echo "== Case 6: partial failure =="
rc=$(run_mirror "DIFF:a, BADPUSH:b, DIFF:c")
[ "$rc" = 1 ] || fail "expected exit 1 on a failed image, got $rc"
[ "$(status_of DIFF__a)" = "mirrored" ] || fail "image before the failure did not mirror"
[ "$(status_of DIFF__c)" = "mirrored" ] || fail "image AFTER the failure was skipped -- fail-fast regression"
[ "$(status_of BADPUSH__b)" = "failed" ] || fail "failed image not recorded"
grep -q "3 total, 2 mirrored" "$WORK/out.txt" || fail "counts wrong: $(grep Images "$WORK/out.txt")"
echo "  all 3 processed, run marked failed"

# --- Case 7: empty list is an error, not a silent success ------------------
echo "== Case 7: empty image list =="
rc=$(run_mirror "  ,  ")
[ "$rc" = 1 ] || fail "empty list should fail, got $rc"
echo "  hard-fails as intended"

# --- Case 8: list parsing (whitespace, dupes) ------------------------------
echo "== Case 8: list parsing =="
rc=$(run_mirror " SAME:x ,SAME:x,  DIFF:y ")
[ "$(ls "$WORK/status" | wc -l)" = 2 ] || fail "expected 2 unique images, got $(ls "$WORK/status" | wc -l)"
echo "  trimmed and de-duplicated"

echo "ALL CHECKS PASSED"
