# Luna-maxing — Codex builds and reviews, Claude orchestrates

## What it is

Luna-maxing is the tandem build mode for a large, stacked change: Claude holds the plan and
ledger while Codex Luna max seats implement and review in separate processes. It turns a goal into
small worktrees, draft PRs, and a gate-backed review loop.

## How it differs from the loop's maker/checker

The loop's checker panel is a group of Claude subagents inside one session. Luna-maxing moves
both implementation and review to Codex seats in separate processes, and the orchestrating
session never writes product code. The maker is not merely a different seat from the checker:
the maker is Codex Luna max, while Claude is the orchestrator.

## When the loop hands a goal over

| Reason | What makes it sufficient |
|---|---|
| Several PRs are needed | The goal decomposes into a dependency-ordered stack whose tasks need separate branches and review boundaries. |
| Security-critical work or migrations | The change touches an invariant, authorization boundary, tenant data, or a migration whose replay needs its own gate. |
| An independent second model is worth its cost | A fresh Codex implementation and review provide evidence that the risk justifies the additional seat and usage. |
| Repeated failure | A new implementation/review pair tests the hypothesis in `handover.md`. |

The handoff is sufficient only when the acceptance criteria, constraints, base commit, worktree,
and local-green commands are written down. A vague request for another model is not a handoff.

## When it does not

- A goal fits one loop iteration with one clear acceptance test and no stacked dependency.
- An optimization goal needs the loop's baseline and keep-or-revert machinery; it has no place
  in a stacked-PR harness.
- The project has no Codex CLI, or the account cannot access `gpt-5.6-luna` at maximum effort.

## The seam

The loop's spine remains the source of truth. The Luna ledger carries per-plan detail beneath it:

| Loop spine | Luna-maxing state |
|---|---|
| `GOALS.md` slice | Plan tasks and their dependency order |
| `BOARD.md` entry | Ledger progress lines for the current goal |
| `handover.md` | Numbered rulings plus the draft-PR list in the ledger |
| `audits/<date>-<goal>.md` | Codex review files and security evidence |

`BOARD.md` remains authoritative for whether the goal is open, in progress, done, or blocked.
The ledger records how the stacked plan reached that state; it cannot override the board.

## The handoff protocol

1. The loop decides that the goal meets one of the handoff reasons and records the acceptance
   slice and current state in `BOARD.md` and `handover.md`.
2. The orchestrator writes the source spec, constraints, plan, task brief, and numbered rulings
   in the plan workspace. The constraints file is copied from
   `skills/luna-maxing/templates/constraints.md` and completed before dispatch.
3. The orchestrator records the full base commit, creates one worktree and branch per task, and
   keeps the stack order in the ledger.
4. Each implementer prompt combines `skills/luna-maxing/templates/headers.md` with
   `skills/luna-maxing/templates/implementer.md`. Dispatch it in the background with
   `skills/luna-maxing/scripts/dispatch.sh`; the worktree and report paths stay in the prompt.
5. After a task commits, the orchestrator runs
   `skills/luna-maxing/scripts/gates.sh` with the project's profile and dispatches a fresh
   reviewer using `skills/luna-maxing/templates/reviewer.md`.
6. Review findings are ruled in the ledger, then the implementer thread resumes with
   `skills/luna-maxing/templates/fix-round.md`. A fresh scoped re-review uses
   `skills/luna-maxing/templates/rereview.md`; repeat until the review and gates are clean.
7. The orchestrator records the exact green head and opens the stacked draft PRs in dependency
   order. The draft-PR list and every open gate remain in the ledger.

## Handing back

While draft PRs are open and unmerged, the loop keeps the `BOARD.md` entry in progress, records
the branch, head, review verdict, gates, and draft-PR list in `handover.md` and the ledger, and
does not mark the goal done merely because a draft exists. The orchestrator remains responsible
for gates, rebases, and every push.

A later session starts with the spine: `GOALS.md`, `BOARD.md`, and `handover.md`, then reads the
ledger and live branch or PR state. It resumes the next open review, fix round, rebase, or gate;
if the stack merged, it records the completion and advances the board.

## What still binds

Moving work to Codex seats does not suspend the loop's guardrails. Every seat reads the completed
constraints file, which is the only document every seat is required to read. It must transcribe
the repository rules, user attribution and writing rules, security invariants, naming and wording
bans, data-retention limits, tenant and fail-polarity rules, and the definition of local green.
No seat pushes, edits a PR, weakens a gate, or treats an unverified claim as evidence.

## Requirements and activation

The mode requires Claude Code, the Codex CLI, the
`superpowers:subagent-driven-development` skill, a Codex account with access to
`gpt-5.6-luna`, and a git worktree-capable checkout. Install the repository as described in the
[README install instructions](../README.md#install).

Claude Code discovers skills one level below the skills directory. After installing the
repository, the bundled copy at `~/.claude/skills/autonomous-loop/skills/luna-maxing` is inert
until it is linked or copied to `~/.claude/skills/luna-maxing`; the activation command and the
copy fallback are in `README.md`. Start a new Claude Code session after activation.
