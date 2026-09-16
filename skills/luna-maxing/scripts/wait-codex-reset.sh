#!/usr/bin/env bash
# Block until a Codex usage limit resets, then prove the model answers again.
# Usage: wait-codex-reset.sh "7:53 PM"      (the RESET_AT value dispatch.sh printed)
# Run with the harness's background mode; it notifies on exit.
set -uo pipefail
export PATH="/opt/homebrew/bin:$PATH"
reset=${1:?reset time like "7:53 PM"}
now=$(date +%s)
target=$(date -j -f "%I:%M %p" "$reset" "+%s" 2>/dev/null || date -d "$reset" "+%s")
# a reset time earlier than now (by more than a minute) means tomorrow
if [ "$target" -lt $((now - 60)) ]; then target=$((target + 86400)); fi
target=$((target + 60))
until [ "$(date +%s)" -ge "$target" ]; do sleep 30; done
for i in 1 2 3 4 5; do
  # capture first and match with a here-string: under pipefail any `producer | grep -q` fails when
  # grep exits on the first match and the producer is killed by SIGPIPE
  reply=$(codex exec -m "${LUNA_MODEL:-gpt-5.6-luna}" -c "model_reasoning_effort=\"${LUNA_EFFORT:-max}\"" \
       --skip-git-repo-check --ephemeral -s read-only "Reply with exactly: LUNA_OK" 2>&1 || true)
  if grep -q '^LUNA_OK' <<< "$reply"; then
    echo "CODEX_READY $(date +%H:%M)"; exit 0
  fi
  sleep 120
done
echo "CODEX_STILL_UNAVAILABLE $(date +%H:%M)"; exit 1
