---
name: luna-maxing
description: Use when the user asks for Luna-maxing, or to build an epic, multi-milestone plan or stacked set of PRs with Codex agents (gpt-5.6-luna, max effort) doing the implementation and review while Claude only orchestrates; also when resuming such a build after a context reset, a Codex usage limit, or a model capacity error.
license: Apache-2.0
version: 1.0.0
---

# Luna-maxing

## Overview

Tandem build: **Claude orchestrates, Codex builds and reviews.** Every line of product code, every fix and every review verdict comes from a Codex seat (`codex exec -m gpt-5.6-luna`, effort `max`). The Claude session plans, rules on ambiguities, dispatches, runs the local gates itself, and owns git and draft PRs. Nothing is pushed until the controller's own gates are green on that exact head AND the Codex review is clean.

**REQUIRED SUB-SKILL:** superpowers:subagent-driven-development (ledger, briefs, review packages, fix-loop discipline). This skill replaces its subagents with Codex seats.

## Roles

| Seat | Who | Session |
|---|---|---|
| Orchestrator: plan, rulings, dispatch, gates, git, rebases without conflicts, draft PRs, ledger | Claude | this session |
| Implementer, fixer, conflict-resolving rebase job | Codex Luna max | implementer thread, resumed for fixes |
| Reviewer, scoped re-reviewer | Codex Luna max | fresh session every time |

The controller never edits product code. A controller "quick fix" skips review.

## Quick reference

| Step | Tool |
|---|---|
| Dispatch a seat (background) | `LUNA_WS=<ws> scripts/dispatch.sh NAME WORKTREE PROMPT` (`--resume THREAD` for fixes) |
| Wait out a usage limit | `scripts/wait-codex-reset.sh "<RESET_AT>"` (background) |
| Local green | `LUNA_WS=<ws> LUNA_GATES_PROFILE=profiles/<project>.sh scripts/gates.sh NAME WORKTREE BASE [args]` |
| Prompt bodies | `templates/implementer.md`, `reviewer.md`, `rereview.md` |
| Prompt headers, fix round, rebase job, continuation | `templates/headers.md`, `fix-round.md`, `rebase-job.md`, `continue.md` |
| Constraints file (worked example), seed lessons | `templates/constraints.md` (`examples/constraints-example-saas.md`), `templates/lessons.md` |
| Gate profiles | `profiles/example-fullstack.sh` (full example), `profiles/example-minimal.sh` (template), `profiles/autonomous-loop.sh` (repository gate) |
| Setup, loop, stacking, failure playbook | `reference.md` |

Paths are relative to this skill's directory. Scripts and templates are the working versions; adapt headers per task, never the review rubric.

## The loop (per task)

1. Worktree per task branch; record BASE.
2. Implementer dispatch = header (brief path, constraints path, spec sections, worktree, report path, controller notes, lessons) + implementer body.
3. On completion: reviewer (fresh) and gates in parallel.
4. Findings: rule in the ledger where needed; resume the implementer thread with the findings verbatim; scoped re-review of the fix diff plus gates. Repeat until clean.
5. Push, open a DRAFT PR stacked on the previous task's branch, ledger the completion.

Details, stacking and rebase handling: `reference.md`.

## Standing rules

- At most two Codex seats run at once, each in its own worktree.
- Every seat runs in the background; the harness notifies on exit. Never poll in the foreground.
- Prompts carry file paths, not pasted content; reports and reviews come back as files.
- Every decision taken on the user's behalf is a numbered ledger ruling with its cost if wrong, and is carried into the next dispatch and the re-review header.
- Gates include suites that only run after merge, compare pre-existing failures structurally, confirm targeted tests ran rather than skipped, and check the tree is clean at start and end.
- Draft PRs only; never merge; follow the user's attribution and PR-writing rules (check commit bodies in gates).
- Acceptance that needs a deployed environment is an open gate listed in the PR body, never simulated.
- Usage limit or capacity error: wait and re-dispatch the same model (see the playbook); do not hand the seat to another model.

## Red flags

| Thought | Reality |
|---|---|
| "Faster if I fix this one line myself" | Unreviewed controller code. Resume the implementer. |
| "Codex is rate-limited, Claude can take this review" | The user chose Codex seats. Wait for the reset. |
| "The implementer says tests pass" | Claims are not gates. Run gates.sh on the exact head. |
| "PR CI is green enough" | Post-merge-only workflows exist. Read the triggers. |
| "Review aborted halfway, findings so far are enough" | An aborted review wrote nothing. Re-dispatch fresh. |
| "Rebase conflict is trivial, resolve it here" | Conflict resolution is code. Codex rebase job, then range-diff review. |
