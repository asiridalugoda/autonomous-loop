# Autonomous Loop

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) **skill** for running long,
unattended, multi-goal work — the kind where a human isn't approving each step. You describe
the objective once; the loop decomposes it into verifiable goals and builds them one at a time
with a maker/checker split, keeping all its state on disk so any fresh session can resume
exactly where it left off. It drives both feature work (test-driven goals) and open-ended
optimization (metric-driven, keep-or-revert), and it rides through API/usage-limit
interruptions by scheduling its own resume instead of dying. With **Luna-maxing**, Codex Luna max
seats build and review stacked changes while Claude orchestrates. With **Relay**, two or more
Claude instances on different machines can run the same loop on the same repo and hand
work to each other autonomously — no human copy-paste in between. With the **Buddy System**,
one Opus session directs a build across several model providers — Codex and Grok alongside
Sonnet and Haiku — so no lane is checked by the provider that built it.

> **Trigger it** with phrases like *"keep working without me"*, *"run the loop"*,
> *"grind through this backlog unattended"*, *"self-improving loop"*, or *"autonomous loop"* —
> Claude Code loads the skill automatically. You can also invoke it directly as
> `/autonomous-loop`.

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](./LICENSE)
&nbsp;·&nbsp; Claude Code skill &nbsp;·&nbsp; v1.6.0

---

## What it does

- **Externalized spine** — all state (goals, board, handover, audits) lives in plain files on
  disk, so any fresh session resumes with zero lost context.
- **Maker ≠ checker** — the agent that implements a goal never grades it; an independent panel
  (plus a red-team + audit on security-critical changes) signs off before it's done.
- **Luna-maxing handoff** — Codex seats implement and review stacked changes while Claude keeps
  the plan, gates, ledger, git and draft PRs.
- **Two goal shapes** — binary spec goals (TDD red→green) *and* metric-driven optimization
  goals (baseline → change in a worktree → keep-or-revert), logged to `EXPERIMENTS.md`.
- **Interruption-resilient** — a rate/usage-limit hit is a pause, not a failure: the loop
  schedules a one-shot, state-checking resume (push, don't merge) and picks up the same step.
- **Guarded self-revision** — the loop sharpens its own "what works here" heuristics over time,
  but can never weaken a guardrail or security invariant.
- **Unattended modes** — one long session, a nightly self-improving cron, or resume-from-spine.
- **Multi-agent coordinator** — on Anthropic's [Managed Agents API](https://platform.claude.com/docs/en/managed-agents/multi-agent),
  run the roles as a persistent **coordinator + roster** (maker, code-reviewer, security-auditor,
  red-team, verifier — one agent each), where maker ≠ checker is enforced by the *topology*, not
  just discipline, and only the coordinator can ship.
- **Relay (multi-node)** — say *"autonomous-loop relay"* and instances on different machines
  (mac↔win, mac↔mac, win↔win) coordinate through the repo's own GitHub issues: a
  controller directs, a worker executes on its box, labels pass the baton.
- **Buddy System (multi-provider)** — say *"autonomous-loop buddy system"* and an Opus Boss
  runs each round across providers: Codex architects and builds, Grok reviews and attacks,
  Sonnet and Haiku build, and the mode degrades on its own to Claude-only seats when a
  provider hits its limit. One stacked PR per round.

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
are harmless — Claude Code only needs `SKILL.md`, `references/` and (for the Buddy System)
`buddy-system/`.

Restart Claude Code (or start a new session) after completing installation and activation so it
will pick the skill up.

### Activate the bundled Luna-maxing skill

Claude Code discovers skills one directory below the skills directory. The bundled copy at
`~/.claude/skills/autonomous-loop/skills/luna-maxing` is inert until it is linked or copied to
`~/.claude/skills/luna-maxing`:

```sh
ln -s ~/.claude/skills/autonomous-loop/skills/luna-maxing ~/.claude/skills/luna-maxing
```

On a filesystem or setup where a symlink is not wanted, copy the skill instead:

```sh
cp -R ~/.claude/skills/autonomous-loop/skills/luna-maxing ~/.claude/skills/luna-maxing
```

Luna-maxing additionally needs the `superpowers:subagent-driven-development` skill, the Codex CLI
and account access to `gpt-5.6-luna`.

**Requires:** Claude Code with skills enabled. The loop leans on Claude Code features —
subagents for the checker panel, git worktrees for isolated parallel makers, and optionally
Workflow scripts / scheduled wake-ups for unattended runs. The Buddy System can optionally
use the Grok CLI and the Codex CLI; without them it runs with Claude seats only.

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

### Multi-agent coordinator

On Anthropic's [Managed Agents API](https://platform.claude.com/docs/en/managed-agents/multi-agent)
the roles become a persistent **coordinator + roster** instead of subagents you dispatch and
discard. Each role is its own agent — a maker, a code-reviewer, a security-auditor, a red-team, a
verifier — with its own model, prompt, and tools. The coordinator holds the spine and delegates;
the maker *can't* grade its own work because the coordinator can't ask it to (maker ≠ checker
becomes the topology); and only the coordinator carries push/merge/deploy, so a worker literally
can't ship. The concrete wiring — roster map, create-coordinator snippet, thread observability,
and the capability-boundary guardrail — is in
[`references/multi-agent-coordinator.md`](./references/multi-agent-coordinator.md).

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

## Relay — two Claudes, two machines, one loop

Fixing something on a Windows box while driving the investigation from a Mac? Before
Relay that meant a human copy-pasting between two sessions. Relay removes the human
message bus: instances on different machines run this same loop **on the same repo**, and
the repo is the only meeting point — mac↔win, mac↔mac, win↔win, all identical.

**Setup** — in a clone of the target repo, say:

```
autonomous-loop relay
```

First run: a short wizard detects your remote and `gh` auth, warns if the repo is
public, asks what may be delegated to remote workers, confirms — then creates the
labels, writes a `## Relay` section into the master file (`docs/loop/LOOP.md`), and
pushes. On every other machine it's just: clone the repo, say the same phrase — the
master file teaches the new node everything.

**How a job runs** — one GitHub issue per job, on the target repo itself:

```
issue #12  controller: mac-studio · worker: win-desktop
────────────────────────────────────────────────────────
mac   → TASK 1: "where vcruntime140.dll; run app.exe --verbose; capture err.log"
        label → awaiting:worker
win   → "claiming TASK 1" · label → working
        executes, redacts, commits log to docs/loop/relay/12/logs/
      → RESULT 1: dll present, crash persists — full log linked
        label → awaiting:controller
mac   → updates issue body + handover.md, dispatches TASK 2 …
        … until a verification TASK passes on the worker → resolved, issue closed
```

The **controller** owns analysis, hypotheses, and authored fixes (for code jobs it
pushes a fix branch; the task is "checkout, build, test, report"). The **worker**
executes exactly as scoped on its own box and reports facts. Labels are the baton —
only the holder acts, one task outstanding at a time, and the worker *claims* before
executing so a duplicate watcher firing can never re-run a state-mutating task. Each
node watches with its live session (`/loop`, ~1–2 min round-trips) plus an OS-scheduler
backstop (launchd / Task Scheduler) firing a headless, idempotent watcher every ~5
minutes — sessions can die, sleep, or reboot and the run continues. Joining a node
**registers and verifies** that scheduler entry (or records an explicit opt-out) — a
node isn't watching until the entry provably exists. And watchers **die with the
work**: a pass that finds no open job binding its node removes its own scheduler entry
and stops polling, so a finished job never leaves orphaned crons behind.

**Relay's own guardrails:** on public repos anyone can comment on your issues — so only
comments from accounts registered in the node table count as instructions, and
everything else (including instruction-shaped text inside captured logs) is data. Logs
are redacted before they're committed. Destructive operations need an explicit
human-authorized marker in the task. Three failed round-trips on one hypothesis
escalates to a `needs:human` label instead of thrashing.

Templates (wizard, master-file section, comment formats, scheduler snippets):
[`references/relay-template.md`](./references/relay-template.md). Worked examples,
including failure drills:
[`references/relay-scenarios.md`](./references/relay-scenarios.md).

---

## Luna-maxing — Codex builds and reviews, Claude orchestrates

Luna-maxing is a tandem build mode for a large, stacked change. Claude holds the plan, rulings,
ledger, git, gates and draft PRs; Codex Luna max seats implement and review in separate processes.
The orchestrating session never writes product code.

| Seat | Work |
|---|---|
| Claude orchestrator | plan, dispatch, rulings, gates, git, rebases, ledger, draft PRs |
| Codex Luna max implementer | implementation, fixes and conflict-resolving rebase jobs |
| Codex Luna max reviewer | fresh review and scoped re-review |

### Per-task loop

1. The orchestrator records the goal slice, constraints, acceptance criteria, base commit and
   worktree in the plan ledger.
2. An implementer runs from the task brief and commits locally on its task branch.
3. The orchestrator runs the repository's gates and sends a fresh reviewer the review package.
4. Findings become ledger rulings; the implementer resumes for a fix round, then a fresh
   re-review and gates repeat until clean.
5. Clean tasks become dependency-ordered draft PRs. The loop keeps `BOARD.md` authoritative while
   the stack is open and unmerged.

Reach for Luna-maxing when the goal is a stack of several PRs, security-critical or migration
work, worth the cost of an independent second model, or repeatedly failing under the loop's own
maker/checker flow. An optimization goal belongs in the loop's baseline and keep-or-revert
machinery. A project without the Codex CLI or access to `gpt-5.6-luna` cannot use this mode.

It requires Claude Code, the Codex CLI, the `superpowers:subagent-driven-development` skill,
access to `gpt-5.6-luna` at maximum effort, and a git worktree-capable checkout. Activate the
bundled skill first; the copy at
`~/.claude/skills/autonomous-loop/skills/luna-maxing` is inert until it is linked or copied to
`~/.claude/skills/luna-maxing`. The [handoff reference](./references/luna-maxing.md) describes
the seam and protocol; the [bundled skill](./skills/luna-maxing/SKILL.md) contains the operating
instructions.

---

## Buddy System — one Boss, many providers

The base loop already splits the maker from the checker. The Buddy System goes a step
further: **the checker comes from a different model provider than the maker**, and many
lanes build at once. One Opus session is the **Boss**; every other seat executes a written
brief and reports back, and nothing a seat claims counts until the Boss re-runs the gates on
the integrated head.

**Start it** — in a repo with (or about to get) a loop spine, say:

```
autonomous-loop buddy system
```

First run: a short wizard detects your toolchain, test commands, git identity and which
providers are installed, asks for the commit identity, push authority, gate and the areas
that need a security round — then writes a `## Buddy System` profile section into
`docs/loop/LOOP.md`. Every later run reads that profile and resumes from the round recorded
on `BOARD.md`. Project-specific settings live in your repo, never in the skill.

### The seats

| Seat | Model | Job |
|---|---|---|
| **Boss** | Claude Opus (this session) | rulings, briefs, local merges, gates, disk floor, git, the PR |
| **Architect** | Astra (`gpt-6-astra`, Codex) | lanes with disjoint files, contracts, risks, test plan per round |
| **Builders (Claude side)** | Sonnet lead + Haiku swarm | Sonnet builds the judgement-heavy core; Haikus do exact-change satellites in parallel |
| **Builders (Codex side)** | Sol orchestrating Luna (`gpt-6-luna`) | whole lanes with settled contracts — backend logic, written-schema migrations, test-heavy work |
| **Lane reviewer + security tester** | Grok (`grok-4.7`) | GO/NO-GO per lane; abuse tests in a scratch clone for security-relevant rounds |
| **Merge reviewer** | Sol (`gpt-6.1-sol`) | the whole round's diff and PR body, when Codex built nothing that round |
| **Re-reviewer** | Luna | fast scoped re-checks of Claude-built fixes |

**Maker ≠ checker, across providers:** a Claude-built lane is reviewed by Grok (or Sol), a
Codex-built lane by Grok — never by Sol or Luna — and a Grok-built lane by Sol.

### Provider modes — degrade, don't wait

A provider probe runs at the start of every round and whenever a Grok or Codex seat hits its
limit. The build keeps going in whatever mode is available, and upgrades again when the
provider is back:

| Mode | When | What changes |
|---|---|---|
| `FULL` | Grok and Codex both available | the full roster above |
| `NO-CODEX` | Codex limited or missing | Opus subagent architects; Grok reviews everything; no Codex builders |
| `NO-GROK` | Grok limited or missing | Sol reviews Claude-built lanes; Opus subagents review Codex-built lanes and run the security round |
| `CLAUDE-ONLY` | neither available (or pinned) | Sonnet and Haiku build; Opus subagents architect, review and attack |

### One round

```
round 3  mode=FULL  base=round-2 PR head
──────────────────────────────────────────────────────────────
Astra  → lanes A (auth guard), B (billing export), C (docs + flags); contracts
Boss   → rulings; contracts committed as the round's baseline; briefs written
build  → Sonnet: lane A core   · Haiku ×3: lane A/C satellites
         Sol → Luna: lane B (own clone)                         (all in parallel)
Boss   → merge each lane --no-ff, re-gate after every merge
review → Grok: A GO · B NO-GO (1 finding) · C GO
         Grok security round on A → PASS (attack tests adopted as guards)
fix    → lane B back to Sol → Luna; Grok re-review → GO
verify → Boss gate on the integrated head: build, lint, unit, every CI
         integration pattern with pass/skip counts, authors, trailers, ratchet
merge  → Grok merge review (Codex built lane B) → APPROVE
push   → PR #57, based on round 2's PR #54; BOARD + handover updated → round 4
```

Rounds stack: each PR is based on the previous round's branch, so building never waits for a
merge. The stack is merged together at the end — **only on your word**.

### Flags

Flags compose: `autonomous-loop buddy system --local --rounds 2 --mode claude-only` (all but
`--local` with `relay`, which needs pushes). The active flags are written to `BOARD.md`, so a
resumed or scheduled session keeps them: a `claude-only` run never quietly becomes `FULL`.

| Flag | Effect |
|---|---|
| `--mode <full\|no-codex\|no-grok\|claude-only>` | Pin a mode ceiling. `claude-only` skips the provider probe, needs no external CLI and sends no code to another provider. |
| `--local` | Build, review and gate locally on `buddy/round-<n>` branches; push nothing, open no PR or issue. |
| `--rounds <n>` | Stop after `n` rounds — the bounded batch for a scheduled or overnight run. |
| `--plan <path>` | Build an existing implementation plan; its rows become goals in `GOALS.md`. |
| `relay` | Combine with Relay: the Boss is the controller, and gates that must run on another machine (a Windows build, attached hardware) go to a worker node as relay TASKs. |

### Requirements and cautions

- **Required:** Claude Code with subagents and worktrees, `git`, and an authenticated `gh` for
  stacked PRs.
- **Optional:** the [Grok CLI](https://x.ai) and the [Codex CLI](https://github.com/openai/codex).
  Missing or rate-limited providers just change the mode.
- **Sending code to other providers.** In any mode but `CLAUDE-ONLY`, your code is read by
  xAI and OpenAI models. Pin `--mode claude-only` for code that must not leave Anthropic.
- **The Codex build side runs with full access** inside standalone clones, with cloud
  credentials stripped and briefs that forbid push, PRs and remote calls. If that is not
  acceptable on your machine, pin `--mode no-codex`.
- **Every seat runs through a wrapper** that sets its sandbox and refuses to start below the
  disk floor (10 GB by default); seats commit only through `commit.sh`, with your identity
  and no trailers.

Full runbook — roster, commands, gates, the profile template, and how it composes with Relay,
optimization goals and scheduled runs:
[`references/buddy-system.md`](./references/buddy-system.md). Seat scripts and brief
templates: [`buddy-system/`](./buddy-system/).

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
- **Codex seats stay in their worktrees.** Seats are dispatched with full filesystem access
  (`codex exec -s danger-full-access`) inside their own git worktree, are told never to push, and
  the orchestrating session — not the seat — runs the gates and owns every push.
- **No silent caps & a comprehension-debt guard.** Skipped coverage is logged, not hidden;
  every merged goal must be explainable in plain English or it's a stop signal.

---

## License

Licensed under the **Apache License 2.0** — see [`LICENSE`](./LICENSE).
