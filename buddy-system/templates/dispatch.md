# Standard dispatch messages

`K` is this skill's `buddy-system/` directory (personal install: `~/.claude/skills/autonomous-loop/buddy-system`). `REPO` is the target repo's main checkout. Run every Agent dispatch with the session cwd in `REPO`, or the worktree is created inside whatever clone the cwd points at.

## Sonnet or Haiku lane (Agent tool)
description: `<LANE> <three to five words>`; subagent_type: `general-purpose`; model: `sonnet` or `haiku`; isolation: `worktree`. Prompt:

> Execute the brief at <SCRATCH>/briefs/<lane>.md exactly. Read it and the common.md it names before doing anything. Work only in your worktree. Never push, never merge, never use git stash, no AI attribution in commits; commit only with <COMMIT_CMD>. Return the branch name, head SHA and the report path.

Haiku adds: "If the code does not match the brief, stop and report the mismatch; never improvise."

## Fix round (SendMessage to the lane's builder)
> The <review|security round> of lane/<...> is <NO-GO|FAIL>. Read <findings> in <report path>. In your worktree run `git checkout -B lane/<...>-fix<n> <integrated head>`. Same rules: red first, then green, report both; <COMMIT_CMD> only; never push or stash; do not edit CI configuration. Parallel lanes on this base: <who owns what>; stay out of those files. Rulings: <one numbered ruling per finding>. Gates: <list>. Append "Review round <n>" to <report path> and return the branch, head SHA and new commit SHAs.

## Grok and Codex seats (Bash tool with run_in_background; never `&`)
    bash $K/scripts/workspace.sh review rev-<lane> <sha>          # detached, read-only; re-run to re-point
    bash $K/scripts/grok-seat.sh review $REPO/.claude/worktrees/rev-<lane> <brief> <report>-run.txt
    bash $K/scripts/codex-seat.sh review <worktree> <brief> <report>                       # Sol
    CODEX_MODEL=gpt-6-luna CODEX_EFFORT=high bash $K/scripts/codex-seat.sh review <worktree> <brief> <report>   # Luna
    bash $K/scripts/codex-seat.sh architect <worktree> <brief> <report>                    # Astra

    bash $K/scripts/workspace.sh clone sec-<round> <sha>           # standalone clone for Grok build or security
    GROK_MAX_TURNS=220 bash $K/scripts/grok-seat.sh security $REPO/.claude/worktrees/sec-<round> <brief> <report>-run.txt
    bash $K/scripts/workspace.sh drop sec-<round> <SCRATCH>/sec-<round>-tests   # saves the tester's uncommitted tests

## Codex build side (Bash tool with run_in_background; never `&`)
    bash $K/scripts/workspace.sh clone codex-hub-<round> <sha>     # Sol's hub; Sol clones one more per lane
    bash $K/scripts/codex-seat.sh orchestrate $REPO/.claude/worktrees/codex-hub-<round> <wave-brief> <report>
    git fetch $REPO/.claude/worktrees/<lane> lane/<epic>-<lane>:lane/<epic>-<lane>   # the branch the lane brief names

    bash $K/scripts/workspace.sh clone <lane> <sha>                # a single Codex lane, no orchestrator
    bash $K/scripts/codex-seat.sh build $REPO/.claude/worktrees/<lane> <brief> <report>                      # Luna, max effort

grok-seat.sh writes the seat's own report where its brief says and its console to the run file; codex-seat.sh writes the seat's final message to <report>. Templates: architect.md, codex-orchestrator.md, review.md, rereview.md, external-review.md, security.md.
