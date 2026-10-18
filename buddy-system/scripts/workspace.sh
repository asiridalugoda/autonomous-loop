#!/usr/bin/env bash
# Seat workspaces, all under <repo>/.claude/worktrees/<name>.
#   review <name> <sha>   detached worktree for a read-only review seat (re-run to re-point it)
#   clone  <name> <sha>   standalone shared clone on branch seat/<name>, for Grok build and security
#                         seats and Codex orchestrate and build seats (a sandbox cannot write a
#                         linked worktree's .git metadata)
#   drop   <name> [save]  remove it; a clone's uncommitted files are copied to <save> first
# Env: REPO (default: the main checkout of the repository the current directory belongs to)
set -euo pipefail
cmd=${1:?review|clone|drop}; name=${2:?name}
REPO=${REPO:-$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")}
dir=$REPO/.claude/worktrees/$name
case "$cmd" in
  review)
    sha=${3:?sha}
    if [ -d "$dir" ]; then git -C "$dir" checkout -q --detach "$sha"; else git -C "$REPO" worktree add -q --detach "$dir" "$sha"; fi
    echo "$dir at $(git -C "$dir" rev-parse --short HEAD)" ;;
  clone)
    sha=${3:?sha}
    [ -e "$dir" ] && { echo "workspace: $dir exists" >&2; exit 2; }
    git clone -q --shared "$REPO" "$dir"
    git -C "$dir" checkout -q -b "seat/$name" "$sha"
    # Per-clone caches and temp, so a sandboxed seat never writes outside its clone.
    printf '.seat-cache/\n.claude/worktrees/\n' >> "$dir/.git/info/exclude"
    mkdir -p "$dir/.seat-cache/tmp"
    echo "$dir on seat/$name at $(git -C "$dir" rev-parse --short HEAD); TMPDIR=$dir/.seat-cache/tmp GOCACHE=$dir/.seat-cache/go GOTMPDIR=$dir/.seat-cache/tmp" ;;
  drop)
    save=${3:-}
    [ -d "$dir" ] || { echo "workspace: no $dir" >&2; exit 2; }
    if [ -d "$dir/.git" ]; then
      if [ -n "$save" ]; then
        git -C "$dir" status --porcelain --untracked-files=all | awk '{print $2}' | grep -v '^\.seat-cache/' | while read -r f; do
          mkdir -p "$save/$(dirname "$f")"; cp "$dir/$f" "$save/$f"; echo "saved $save/$f"; done
      fi
      rm -rf "$dir"
    else
      git -C "$REPO" worktree remove --force "$dir"
    fi
    echo "dropped $dir" ;;
  *) echo "workspace: unknown command $cmd" >&2; exit 2 ;;
esac
