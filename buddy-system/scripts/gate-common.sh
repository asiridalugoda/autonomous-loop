#!/usr/bin/env bash
# Provenance and copy checks that end every Boss gate, over <base>..HEAD of the current worktree.
# Usage: bash gate-common.sh <base-sha>     (base = the previous round's branch head, or the
#                                            commit round 1 started from)
# Env: BUDDY_AUTHOR_EMAIL     every commit's author and committer email (default: git config user.email)
#      BUDDY_AUTHOR_NAME      and name (default: git config user.name)
#      BUDDY_RATCHET          extended regex no added line may match (empty: skip), e.g. '—|TODO\(ship\)'
#      BUDDY_RATCHET_SKIP     extended regex of paths the ratchet ignores, e.g. '\.go$|^b/vendor/'
# Prints one line per check, then the first offending lines; exits 1 when any count is non-zero.
set -uo pipefail
BASE=${1:?base sha}
EMAIL=${BUDDY_AUTHOR_EMAIL:-$(git config user.email || true)}
NAME=${BUDDY_AUTHOR_NAME:-$(git config user.name || true)}
[ -n "$EMAIL" ] && [ -n "$NAME" ] || { echo "gate-common: set BUDDY_AUTHOR_NAME and BUDDY_AUTHOR_EMAIL" >&2; exit 2; }
ID="$NAME <$EMAIL>"
git rev-parse -q --verify "$BASE^{commit}" >/dev/null || { echo "gate-common: unknown base $BASE" >&2; exit 2; }

foreign=$(git log --format='%an <%ae>|%cn <%ce>' "$BASE"..HEAD | grep -vxFc "$ID|$ID")
# The same list commit.sh refuses.
trailers=$(git log --format=%B "$BASE"..HEAD | grep -ciE '^(co-authored-by|claude-session):|generated with \[?claude|claude\.ai/code')
ratchet=0
if [ -n "${BUDDY_RATCHET:-}" ]; then
  # ENVIRON, not -v: awk would process backslash escapes in -v values and turn '\.' into '.'.
  hits=$(git diff "$BASE" HEAD | BUDDY_RATCHET_SKIP=${BUDDY_RATCHET_SKIP:-} awk '
    BEGIN     { re = ENVIRON["BUDDY_RATCHET"]; skip = ENVIRON["BUDDY_RATCHET_SKIP"] }
    /^\+\+\+/ { f = $2; next }
    /^\+/     { if ((skip == "" || f !~ skip) && $0 ~ re) print f ": " substr($0, 2) }')
  [ -n "$hits" ] && ratchet=$(printf '%s\n' "$hits" | wc -l | tr -d ' ')
fi

echo "commits $(git rev-list --count "$BASE"..HEAD) ($BASE..$(git rev-parse --short HEAD))"
echo "foreign authors $foreign"
echo "trailers $trailers"
echo "ratchet $ratchet${BUDDY_RATCHET:+ (/$BUDDY_RATCHET/)}"
[ "$foreign" -gt 0 ] && git log --format='%an <%ae>|%cn <%ce>|%h %s' "$BASE"..HEAD | grep -vF "$ID|$ID|" | head -5 | sed 's/^/  /'
[ "$ratchet" -gt 0 ] && printf '%s\n' "$hits" | head -5 | sed 's/^/  /'
[ "$foreign" -eq 0 ] && [ "$trailers" -eq 0 ] && [ "$ratchet" -eq 0 ]
