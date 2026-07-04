# Autonomous Loop

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) **skill** for running long,
unattended, multi-goal work — the kind where a human isn't approving each step. You describe
the objective once; the loop decomposes it into verifiable goals and builds them one at a time
with a maker/checker split, keeping all its state on disk so any fresh session can resume
exactly where it left off. It drives both feature work (test-driven goals) and open-ended
optimization (metric-driven, keep-or-revert), and it rides through API/usage-limit
interruptions by scheduling its own resume instead of dying.

> **Trigger it** with phrases like *"keep working without me"*, *"run the loop"*,
> *"grind through this backlog unattended"*, *"self-improving loop"*, or *"autonomous loop"* —
> Claude Code loads the skill automatically. You can also invoke it directly as
> `/autonomous-loop`.

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](./LICENSE)
&nbsp;·&nbsp; Claude Code skill &nbsp;·&nbsp; v1.2.1

---

## What it does

- **Externalized spine** — all state (goals, board, handover, audits) lives in plain files on
  disk, so any fresh session resumes with zero lost context.
- **Maker ≠ checker** — the agent that implements a goal never grades it; an independent panel
  (plus a red-team + audit on security-critical changes) signs off before it's done.
- **Two goal shapes** — binary spec goals (TDD red→green) *and* metric-driven optimization
  goals (baseline → change in a worktree → keep-or-revert), logged to `EXPERIMENTS.md`.
- **Interruption-resilient** — a rate/usage-limit hit is a pause, not a failure: the loop
  schedules a one-shot, state-checking resume (push, don't merge) and picks up the same step.
- **Guarded self-revision** — the loop sharpens its own "what works here" heuristics over time,
  but can never weaken a guardrail or security invariant.
- **Unattended modes** — one long session, a nightly self-improving cron, or resume-from-spine.

---

## Credit & inspiration

This skill is a direct, practical application of **[Addy Osmani](https://github.com/addyosmani)'s
"loop engineering"**:

> ### 📝 https://addyosmani.com/blog/loop-engineering/
>
> 👤 GitHub: [@addyosmani](https://github.com/addyosmani)

Everything here is an attempt to turn that essay's ideas into a repeatable harness. The four
that do the heavy lifting:

> **"You design the system that does it instead."** — don't do the task by hand; build the
> machine that does the task, then let it run.
>
> **"The model forgets, the repo doesn't."** — externalize all state to files on disk, so any
> fresh session resumes with zero lost context.
>
> **"Split the one who writes from the one who checks."** — the agent that implements a goal
> never grades it. A separate agent verifies. Maker ≠ checker.
>
> **"Verification is still on you."** — autonomy multiplies output, *including mistakes*. The
> guardrails are what keep it from confidently amplifying drift.

Please read the original post — it's the "why" behind every design choice in this skill.

It also borrows from **[Andrej Karpathy](https://github.com/karpathy)'s
[autoresearch](https://github.com/karpathy/autoresearch)**
([@karpathy](https://github.com/karpathy)): the *optimization-goal* mode — one primary metric,
a fixed per-trial budget, and keep-the-commit-or-`git reset` on the result — is that project's
overnight experiment loop, adapted for build work.

---

## Install

The skill is this repository. Drop it into your Claude Code skills directory.

**Personal (all your projects):**

```sh
git clone https://github.com/asiridalugoda/autonomous-loop.git \
  ~/.claude/skills/autonomous-loop
```

**A single project (checked in for your team):**

```sh
git clone https://github.com/asiridalugoda/autonomous-loop.git \
  /path/to/your-project/.claude/skills/autonomous-loop
```

Prefer not to clone? Download the ZIP and copy the folder so that
`~/.claude/skills/autonomous-loop/SKILL.md` exists. The extra files (`README.md`, `LICENSE`)
are harmless — Claude Code only needs `SKILL.md` and `references/`.

Restart Claude Code (or start a new session) and it will pick the skill up.

**Requires:** Claude Code with skills enabled. The loop leans on Claude Code features —
subagents for the checker panel, git worktrees for isolated parallel makers, and optionally
Workflow scripts / scheduled wake-ups for unattended runs.

---

## How it works

All state lives in a **spine** — a few plain Markdown files (ideally under `docs/loop/`) that
hold everything the loop needs. A fresh session resumes by reading them in order and nothing
else:

| File | Holds |
|---|---|
| `LOOP.md` | The runbook: roles, the iteration sequence, guardrails, stopping conditions. |
| `GOALS.md` | The dependency-ordered goal ladder — each goal with a checkable acceptance criterion. |
| `BOARD.md` | Live state of every goal: open / in-progress / done / blocked, with notes. |
| `handover.md` | 2–3 plain-English lines per merged goal, plus any current failure + next hypothesis. |
| `audits/<date>-<goal>.md` | Evidence artifacts for security-critical changes. |
| `EXPERIMENTS.md` | Keep-or-revert ledger for optimization goals (only appears when you run them). |

Ready-to-fill templates for all of these are in
[`references/spine-templates.md`](./references/spine-templates.md).

### One iteration, per goal

```
1. LOAD SPINE   → read project instructions, handover.md, BOARD.md, GOALS.md.
2. PICK GOAL    → the next unblocked goal in dependency order; mark it in-progress.
3. TDD (red)    → write the failing test that encodes this goal's acceptance criterion.
4. IMPLEMENT    → code until green; the boring, obvious solution; touch only what's needed.
5. REVIEW       → an independent checker panel (maker ≠ checker). Red-team on security goals.
6. VERIFY       → a fresh verifier checks the stopping condition against evidence.
7a. PASS        → mark done, append "what changed & why" to handover.md, commit, advance.
7b. FAIL        → record the failure + next hypothesis so the next pass self-unblocks.
8. REPEAT       → until the slice / definition-of-done is met.
```

Independent goals can **fan out** to multiple maker agents at once, each in its own git
worktree so their edits don't collide.

### Two goal shapes

Most goals are **spec goals** — a binary pass/fail acceptance test (TDD red→green), exactly as
the iteration above describes.

For open-ended **optimization goals** ("make it faster / smaller / less flaky") the loop runs a
metric-driven hill-climb instead of a test: measure a baseline, make the change in a throwaway
worktree under a fixed budget, then **keep the commit if the metric improved or revert if
not** — logging every attempt to `EXPERIMENTS.md` so a discarded idea is never re-run. That
discipline is borrowed from [Karpathy's autoresearch](https://github.com/karpathy/autoresearch).

To use one, write the goal in `GOALS.md` with a `📈` metric AC instead of a test:

```markdown
- [ ] **G3.1 Speed up the dashboard query** — 📈 metric AC: p95 latency ↓ ≥10% vs baseline,
      measured with `pnpm bench:dashboard`; keep-or-revert.
```

The loop records a baseline, tries changes one at a time, and keeps only those that move the
number — with the correctness suites still required to stay green, so it can't "win" by
breaking something.

### Running it unattended

- **Interactive-autonomous** — one long session that keeps looping through goals until the
  definition-of-done or an escalation.
- **Scheduled** — a nightly cron / wake-up that triages (failing tests, lint, coverage gaps,
  TODOs → new goals) and runs a bounded batch. This is the "self-improving" mode.
- **Resume** — any new session continues from the spine files, in order.

**Interruptions don't kill the run.** A rate/usage-limit hit, an overload (429/503/529), a
timeout, or a crash is a *pause*, not a failure — and it never counts toward the 3-strikes
escalation. Transient blips get a retry with backoff. For a real usage-limit wall the loop
**actually schedules a one-shot wake-up** just past the reset — in Claude Code, a one-shot
`CronCreate` (fires once, then auto-deletes) or `ScheduleWakeup` — with a **state-first,
idempotent prompt**: it reads the spine + git/PR state, does **nothing** if the run already
finished and pushed cleanly, or **resumes the remaining steps** if it stalled — carrying the
same guardrails (e.g. push to the PR, but never merge).

Those schedulers are session-only, so they cover a *paused* session. If a limit might **kill**
the session, back the resume with a durable trigger — a `/schedule` cloud routine, an external
cron, or a human re-launch — that starts a fresh session on the same prompt. Either way the
spine on disk guarantees the resume picks up the same step with zero lost work.

Over repeated runs the loop also sharpens its own runbook: it appends evidence-backed
heuristics to a **"What works here"** section of `LOOP.md` (e.g. "this suite is flaky under
parallelism — run it single-threaded"). It may refine those notes, but it can **never** edit
the guardrails or security invariants — those stay human-only.

---

## Safety — read this before you let it run

Autonomy multiplies output, including mistakes. This skill has guardrails built in, but you
own the outcome:

- **Maker ≠ checker on every goal.** The agent that writes code never grades it. This is the
  core error-correction; don't collapse the two.
- **Security-critical invariants** (auth, tenant isolation, RBAC, money, safety gates,
  destructive migrations) require the full reviewer panel **+** a red-team **+** a written
  audit artifact before they change.
- **Confirm the irreversible.** Autonomy over *building* is not autonomy over *shipping*.
  Pushing, merging, deploying, and deleting happen only when you've authorized that class of
  action.
- **No silent caps & a comprehension-debt guard.** Skipped coverage is logged, not hidden;
  every merged goal must be explainable in plain English or it's a stop signal.

---

## License

Licensed under the **Apache License 2.0** — see [`LICENSE`](./LICENSE).
