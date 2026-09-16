#!/usr/bin/env bash
# Controller-run "local green" gate for one worktree. The controller runs this itself
# before every push; implementer claims never substitute for it.
#
# Usage: LUNA_WS=<workspace> LUNA_GATES_PROFILE=<profile.sh> gates.sh NAME WORKTREE BASE [profile args...]
# The profile defines project_gates() and calls `run LABEL 'COMMAND'` for each gate;
# profile args (for example --e2e REGEX, --dashboard) are passed to project_gates.
# Writes $LUNA_WS/NAME-gates.log; prints PASS/FAIL per gate; exits non-zero on any failure.
set -uo pipefail
: "${LUNA_WS:?set LUNA_WS}"; : "${LUNA_GATES_PROFILE:?set LUNA_GATES_PROFILE}"
export PATH="/opt/homebrew/bin:$PATH"
name=$1; wt=$2; base=$3; shift 3
log="$LUNA_WS/$name-gates.log"; : > "$log"
fail=0
run() { # LABEL COMMAND (evaluated inside the worktree root)
  local label=$1; shift
  echo "=== $label: $*" >> "$log"
  if (cd "$wt" && eval "$@") >> "$log" 2>&1; then echo "PASS $label"; else echo "FAIL $label"; fail=1; fi
}
export -f run 2>/dev/null || true

run "clean tree at start" 'test -z "$(git status --porcelain)"'
run "no AI attribution in commits" '! git log --format=%B '"$base"'..HEAD | grep -iE "co-authored-by|claude-session|generated with|claude\\.ai/code|chatgpt\\.com/codex"'

# shellcheck source=/dev/null
source "$LUNA_GATES_PROFILE"
project_gates "$@"

run "clean tree at end" 'test -z "$(git status --porcelain)"'
echo "log: $log"
exit $fail
