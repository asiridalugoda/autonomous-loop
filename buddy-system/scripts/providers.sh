#!/usr/bin/env bash
# Probe which external providers can take a seat right now, and print the build mode.
# Usage: bash providers.sh            -> e.g. "grok=ok codex=limited mode=NO-CODEX"
# Run at session start, at the start of every round, and whenever a Grok or Codex seat exits 75.
# Modes (references/buddy-system.md, "Provider modes"):
#   FULL         Astra, Sol, Luna (Codex) and Grok all available
#   NO-CODEX     Grok available, Codex limited or missing
#   NO-GROK      Codex available, Grok limited or missing
#   CLAUDE-ONLY  neither: Opus boss, Sonnet and Haiku build, Opus subagents check
# Env: GROK_BIN, GROK_MODEL (default grok-4.7), CODEX_PROBE_MODEL (default gpt-6-luna).
set -uo pipefail
export PATH="/opt/homebrew/bin:$HOME/.local/bin:$PATH"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
echo "Reply with exactly: SEAT_OK" > "$tmp/p.md"
limited_re='usage limit|rate.?limit|429|quota|insufficient (credits|balance)|exceeded|billing|unauthori[sz]ed|401|try again at'

grok=missing
G=${GROK_BIN:-$HOME/.grok/bin/grok}
[ -x "$G" ] || G=$(command -v grok || true)
if [ -n "$G" ] && [ -x "$G" ]; then
  "$G" --cwd "$tmp" --prompt-file "$tmp/p.md" -m "${GROK_MODEL:-grok-4.7}" --max-turns 1 \
    --sandbox read-only --output-format plain --no-auto-update > "$tmp/g.out" 2>&1; rc=$?
  if grep -q 'SEAT_OK' "$tmp/g.out"; then grok=ok
  elif [ $rc -ne 0 ] && grep -qiE "$limited_re" "$tmp/g.out"; then grok=limited
  else grok=error; fi
fi

codex=missing
if command -v codex >/dev/null 2>&1; then
  export CLOUDSDK_CONFIG="$tmp/.no-gcloud"; mkdir -p "$CLOUDSDK_CONFIG"
  codex exec -m "${CODEX_PROBE_MODEL:-gpt-6-luna}" -c 'model_reasoning_effort="low"' -s read-only -C "$tmp" \
    --skip-git-repo-check --json -o "$tmp/c.md" - < "$tmp/p.md" > "$tmp/c.jsonl" 2> "$tmp/c.err"
  if grep -q 'SEAT_OK' "$tmp/c.md" 2>/dev/null; then codex=ok
  elif grep -qiE "$limited_re" "$tmp/c.jsonl" "$tmp/c.err" 2>/dev/null; then codex=limited
  else codex=error; fi
fi

case "$grok/$codex" in
  ok/ok) mode=FULL ;;
  ok/*)  mode=NO-CODEX ;;
  */ok)  mode=NO-GROK ;;
  *)     mode=CLAUDE-ONLY ;;
esac
echo "grok=$grok codex=$codex mode=$mode"
