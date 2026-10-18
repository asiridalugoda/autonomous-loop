#!/usr/bin/env bash
# Run one Grok CLI seat headlessly with the isolation its role needs.
# Usage: bash grok-seat.sh <build|review|pr-review|security> <workdir> <brief-file> <report-file>
# Env: GROK_BIN (default ~/.grok/bin/grok, else grok on PATH), GROK_MODEL (default grok-4.7),
#      GROK_EFFORT (default high), GROK_MAX_TURNS, DISK_FLOOR_GB (default 10).
# Exit codes: the CLI's own; 75 quota or auth limit (re-probe with providers.sh); 3 below the
# disk floor; 2 bad args.
set -uo pipefail
# Run from a private copy: bash reads a script as it runs, so editing this file while a seat is
# live would otherwise break that seat's run. export -n keeps the marker out of the seat's own
# environment, so a nested seat (Sol starting a Luna build) makes its own copy too.
if [ -z "${SEAT_SCRIPT_COPY:-}" ]; then
  c=$(mktemp "${TMPDIR:-/tmp}/seat-script.XXXXXX"); cp "$0" "$c"; SEAT_SCRIPT_COPY=$c exec bash "$c" "$@"
fi
trap 'rm -f "$SEAT_SCRIPT_COPY"' EXIT; export -n SEAT_SCRIPT_COPY
role=${1:?role}; dir=${2:?workdir}; brief=${3:?brief file}; out=${4:?report file}
GROK=${GROK_BIN:-$HOME/.grok/bin/grok}
[ -x "$GROK" ] || GROK=$(command -v grok || true)
[ -n "$GROK" ] || { echo "grok-seat: no grok CLI (set GROK_BIN)" >&2; exit 2; }
[ -d "$dir" ] && [ -f "$brief" ] || { echo "grok-seat: missing workdir or brief" >&2; exit 2; }
floor=${DISK_FLOOR_GB:-10}
free_gb=$(df -Pk "$dir" | awk 'NR==2{print int($4/1048576)}')
if [ "$free_gb" -lt "$floor" ]; then
  echo "grok-seat: ${free_gb} GB free is below the ${floor} GB floor; clean up before dispatching" >&2
  exit 3
fi

common=(--cwd "$dir" --prompt-file "$brief" -m "${GROK_MODEL:-grok-4.7}"
        --reasoning-effort "${GROK_EFFORT:-high}" --output-format plain --no-auto-update)
# Nothing a seat does may leave the machine or touch shared state.
deny=(--deny 'Bash(git push*)' --deny 'Bash(git stash*)' --deny 'Bash(git reset --hard*)'
      --deny 'Bash(gh pr merge*)' --deny 'Bash(gh pr comment*)' --deny 'Bash(gh pr review*)'
      --deny 'Bash(gh pr create*)' --deny 'Bash(gh pr edit*)' --deny 'Bash(gh issue*)'
      --deny 'Bash(gh api -X*)' --deny 'Bash(gh workflow*)' --deny 'Bash(gh release*)'
      --deny 'Bash(gcloud*)' --deny 'Bash(aws*)' --deny 'Bash(az*)' --deny 'Bash(kubectl*)'
      --deny 'Bash(docker*)' --deny 'Bash(colima*)'
      --deny 'Bash(*curl*|*sh*)' --deny 'Bash(*wget*|*sh*)' --deny 'Bash(sudo*)'
      --deny 'Bash(*make e2e*)' --deny 'Bash(*playwright*)' --deny 'Bash(*tests/e2e*)')
readonly_tools="write,search_replace,StrReplace,EditNotebook,Delete"

case "$role" in
  build)
    "$GROK" "${common[@]}" --sandbox workspace --permission-mode bypassPermissions \
      --max-turns "${GROK_MAX_TURNS:-200}" --disable-web-search "${deny[@]}" > "$out" 2>&1 ;;
  review|pr-review)
    "$GROK" "${common[@]}" --sandbox read-only --disallowed-tools "$readonly_tools" \
      --max-turns "${GROK_MAX_TURNS:-80}" --disable-web-search "${deny[@]}" > "$out" 2>&1 ;;
  security)
    # Writes are limited to the workdir (a standalone scratch clone) and temp; local targets only.
    "$GROK" "${common[@]}" --sandbox workspace --permission-mode bypassPermissions \
      --max-turns "${GROK_MAX_TURNS:-120}" --disable-web-search "${deny[@]}" > "$out" 2>&1 ;;
  *) echo "grok-seat: unknown role $role" >&2; exit 2 ;;
esac
rc=$?
# A failed run whose console reports a quota or auth limit exits 75, so the Boss re-probes the
# providers (providers.sh) and moves the seat to the next mode. A successful run is never read
# for these words: review text often discusses rate limits.
if [ $rc -ne 0 ] && grep -qiE 'usage limit|rate.?limit|429|quota|insufficient (credits|balance)|billing|unauthori[sz]ed|401' "$out"; then
  echo "grok-seat: GROK_LIMITED role=$role; see $out" >&2; exit 75
fi
echo "grok-seat: $role finished (exit $rc); report at $out"
exit $rc
