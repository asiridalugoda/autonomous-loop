#!/usr/bin/env bash
# Run one Codex seat (implementer, fixer, reviewer, re-reviewer, rebase job) non-interactively.
#
# Usage:
#   LUNA_WS=<workspace dir> dispatch.sh NAME WORKTREE PROMPT_FILE
#   LUNA_WS=<workspace dir> dispatch.sh --resume THREAD_ID NAME WORKTREE PROMPT_FILE
#
# Writes $LUNA_WS/NAME.jsonl (event stream; first line carries thread_id),
#        $LUNA_WS/NAME.last.md (final message), $LUNA_WS/NAME.stderr.
# Env: LUNA_MODEL (default gpt-5.6-luna), LUNA_EFFORT (default max),
#      LUNA_CAPACITY_RETRIES (default 6), LUNA_CAPACITY_SLEEP (default 120).
# Exit codes: 0 ok; 75 usage limit hit (reset time printed as RESET_AT=...);
#             76 model at capacity after all retries; other = codex failure.
# Run it with the harness's background mode; never poll it in the foreground.
set -uo pipefail
: "${LUNA_WS:?set LUNA_WS to the plan workspace directory}"
MODEL="${LUNA_MODEL:-gpt-5.6-luna}"
EFFORT="${LUNA_EFFORT:-max}"
RETRIES="${LUNA_CAPACITY_RETRIES:-6}"
SLEEP_S="${LUNA_CAPACITY_SLEEP:-120}"
export PATH="/opt/homebrew/bin:$PATH"

resume=""
if [ "${1:-}" = "--resume" ]; then resume=$2; shift 2; fi
name=$1; wt=$2; prompt=$3
out="$LUNA_WS/$name"

run_once() {
  if [ -n "$resume" ]; then
    (cd "$wt" && codex exec -m "$MODEL" -c "model_reasoning_effort=\"$EFFORT\"" \
      -s danger-full-access --json -o "$out.last.md" \
      resume "$resume" - < "$prompt" > "$out.jsonl" 2> "$out.stderr")
  else
    codex exec -m "$MODEL" -c "model_reasoning_effort=\"$EFFORT\"" \
      -s danger-full-access -C "$wt" --json -o "$out.last.md" \
      - < "$prompt" > "$out.jsonl" 2> "$out.stderr"
  fi
}

attempt=0
while :; do
  attempt=$((attempt + 1))
  run_once; rc=$?
  if grep -q '"type":"error".*usage limit' "$out.jsonl" 2>/dev/null; then
    # formats seen: "try again at 7:53 PM" and "try again at Sep 16th, 2026 12:54 AM"
    reset=$(grep -o 'try again at [^"]*' "$out.jsonl" | head -1 | grep -oE '[0-9]{1,2}:[0-9]{2} ?[AP]M' | head -1)
    echo "USAGE_LIMIT name=$name RESET_AT=$reset"
    exit 75
  fi
  if grep -q '"type":"error".*at capacity' "$out.jsonl" 2>/dev/null; then
    if [ "$attempt" -le "$RETRIES" ]; then
      echo "capacity: retry $attempt/$RETRIES in ${SLEEP_S}s"; sleep "$SLEEP_S"; continue
    fi
    echo "CAPACITY_EXHAUSTED name=$name"; exit 76
  fi
  break
done
thread=$(head -1 "$out.jsonl" 2>/dev/null | sed -n 's/.*"thread_id":"\([^"]*\)".*/\1/p')
echo "exit=$rc name=$name thread=$thread"
tail -c 1500 "$out.last.md" 2>/dev/null || true
exit $rc
