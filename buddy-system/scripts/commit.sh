#!/usr/bin/env bash
# The only way a seat commits: the profile's author and committer, no trailers, no attribution.
# Usage: bash commit.sh "<subject>" ["<body>"]   (stage files first)
# Env: BUDDY_AUTHOR_NAME, BUDDY_AUTHOR_EMAIL (default: git config user.name / user.email)
set -euo pipefail
subject=${1:?subject}; body=${2:-}
NAME=${BUDDY_AUTHOR_NAME:-$(git config user.name || true)}
EMAIL=${BUDDY_AUTHOR_EMAIL:-$(git config user.email || true)}
[ -n "$NAME" ] && [ -n "$EMAIL" ] || { echo "commit.sh: set BUDDY_AUTHOR_NAME and BUDDY_AUTHOR_EMAIL (or git config user.*)" >&2; exit 2; }
msg=$subject; [ -n "$body" ] && msg=$(printf '%s\n\n%s' "$subject" "$body")
if printf '%s' "$msg" | grep -qiE '^(co-authored-by|claude-session):|generated with \[?claude|claude\.ai/code'; then
  echo "commit.sh: refusing a message with a trailer or attribution" >&2; exit 2
fi
GIT_COMMITTER_NAME="$NAME" GIT_COMMITTER_EMAIL="$EMAIL" git -c user.name="$NAME" -c user.email="$EMAIL" commit -q -m "$msg"
git log -1 --format='%h %ae %ce %s'
