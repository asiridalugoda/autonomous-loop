#!/usr/bin/env bash
# Run one Codex seat headlessly with the model and sandbox its role needs.
# Usage: bash codex-seat.sh <architect|orchestrate|build|review> <workdir> <brief-file> <report-file>
#   architect    Astra (gpt-6-astra), read-only: round architecture, lane split, contracts, risks
#   orchestrate  Sol (gpt-6.1-sol), the Codex-side lead: splits a Codex wave into Luna build seats
#                (each in its own standalone clone, via this script), checks each against its brief
#                and gates, and reports the branches; runs in its own standalone hub clone
#   build        Luna (gpt-6-luna) at max effort: one lane, writes and commits in a STANDALONE
#                clone only (workspace.sh clone)
#   review       Sol (gpt-6.1-sol), read-only; CODEX_MODEL=gpt-6-luna for a fast scoped re-review
# orchestrate and build run with full access (danger-full-access) and no cloud credentials; the
# standalone clone and their briefs, which forbid push, stash, PRs and remote calls, are the fence.
# Env: CODEX_MODEL, CODEX_EFFORT (default max; high is enough for a Luna re-review),
#      CODEX_SERVICE_TIER (optional), DISK_FLOOR_GB (default 10).
# Writes <report-file> (the seat's final message), <report-file>.jsonl (event stream) and .stderr.
# Exit codes: 0 ok; 75 Codex usage limit (RESET_AT printed); 3 below the disk floor; 2 bad args.
set -uo pipefail
# Run from a private copy: bash reads a script as it runs, so editing this file while a seat is
# live would otherwise break that seat's run. export -n keeps the marker out of the seat's own
# environment, so a nested seat (Sol starting a Luna build) makes its own copy too.
if [ -z "${SEAT_SCRIPT_COPY:-}" ]; then
  c=$(mktemp "${TMPDIR:-/tmp}/seat-script.XXXXXX"); cp "$0" "$c"; SEAT_SCRIPT_COPY=$c exec bash "$c" "$@"
fi
trap 'rm -f "$SEAT_SCRIPT_COPY"' EXIT; export -n SEAT_SCRIPT_COPY
role=${1:?role}; dir=${2:?workdir}; brief=${3:?brief file}; out=${4:?report file}
[ -d "$dir" ] && [ -f "$brief" ] || { echo "codex-seat: missing workdir or brief" >&2; exit 2; }
floor=${DISK_FLOOR_GB:-10}
free_gb=$(df -Pk "$dir" | awk 'NR==2{print int($4/1048576)}')
if [ "$free_gb" -lt "$floor" ]; then
  echo "codex-seat: ${free_gb} GB free is below the ${floor} GB floor; clean up before dispatching" >&2; exit 3
fi
case "$role" in
  architect) model=${CODEX_MODEL:-gpt-6-astra} ;;
  review)    model=${CODEX_MODEL:-gpt-6.1-sol} ;;
  orchestrate|build)
             if [ "$role" = build ]; then model=${CODEX_MODEL:-gpt-6-luna}; else model=${CODEX_MODEL:-gpt-6.1-sol}; fi
             [ -d "$dir/.git" ] || { echo "codex-seat: $role needs a standalone clone (workspace.sh clone), not $dir" >&2; exit 2; } ;;
  *) echo "codex-seat: unknown role $role" >&2; exit 2 ;;
esac
effort=${CODEX_EFFORT:-max}
export PATH="/opt/homebrew/bin:$HOME/.local/bin:$PATH"
# Seats never act on real cloud accounts: no gcloud credentials reach them.
CLOUDSDK_CONFIG="$(dirname "$out")/.no-gcloud-creds"; export CLOUDSDK_CONFIG; mkdir -p "$CLOUDSDK_CONFIG"
export CLOUDSDK_CORE_DISABLE_PROMPTS=1; unset GOOGLE_APPLICATION_CREDENTIALS
sandbox=read-only; case "$role" in orchestrate|build) sandbox=danger-full-access ;; esac
tier=(); [ -n "${CODEX_SERVICE_TIER:-}" ] && tier=(-c "service_tier=\"$CODEX_SERVICE_TIER\"")
codex exec -m "$model" -c "model_reasoning_effort=\"$effort\"" ${tier[@]+"${tier[@]}"} -s "$sandbox" -C "$dir" \
  --skip-git-repo-check --json -o "$out" - < "$brief" > "$out.jsonl" 2> "$out.stderr"; rc=$?
if grep -q '"type":"error".*usage limit' "$out.jsonl" 2>/dev/null; then
  reset=$(grep -o 'try again at [^"]*' "$out.jsonl" | head -1 | sed 's/try again at //')
  echo "codex-seat: USAGE_LIMIT model=$model RESET_AT=$reset"; exit 75
fi
# A failed run whose stderr reports a rate limit or quota is a limit too. Only a failed run is
# read for these words, and only its stderr: review text often discusses rate limits.
if [ $rc -ne 0 ] && grep -qiE 'rate.?limit|429|quota|insufficient (credits|balance)' "$out.stderr" 2>/dev/null; then
  echo "codex-seat: LIMITED model=$model; see $out.stderr"; exit 75
fi
echo "codex-seat: $role ($model, $effort) exit=$rc; report at $out"
exit $rc
