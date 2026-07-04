# Spine templates

Fill-in scaffolds for the spine files the autonomous loop runs on. Copy each into the
project's `docs/loop/` (or `loop/`) directory during Step 0 bootstrap, replace the
`<angle-bracket>` placeholders, delete the guidance comments, and commit. Keep them lean —
they're read every iteration; bloat costs context on every pass.

---

## `LOOP.md` — the runbook

```markdown
# <Project> — Autonomous Loop (Runbook)

Built on Addy Osmani's Loop Engineering: design the system that does the work; the model
forgets, the repo doesn't; split the maker from the checker; verification is still on you.

## Commands (discover these — don't assume)
- Test:       `<e.g. pnpm test>`
- Lint:       `<e.g. pnpm lint>`
- Typecheck:  `<e.g. pnpm typecheck>`
- Build:      `<e.g. pnpm build>`
- E2E / UAT:  `<e.g. pnpm test:e2e>`

## Security-critical areas (strict panel + red-team + audit artifact to change)
- <e.g. auth / tenant isolation / RBAC / money / a required safety gate / destructive migrations>

## Roles (maker ≠ checker)
- Maker: <which agent type builds — e.g. general-purpose in a worktree>
- Checker panel: <code-reviewer + security-auditor (+ test-engineer)>
- Red-team: <for security gates only>
- Verifier (/goal): a fresh agent, never the maker

## One iteration
LOAD SPINE → PICK GOAL → TDD(red) → IMPLEMENT → REVIEW(+red-team if security) →
VERIFY(/goal) → PASS: mark done + handover + commit  |  FAIL: log hypothesis + reopen → REPEAT

## Personas / UAT (if applicable)
- <persona 1 — the journey it must complete>
- <persona 2 — ...>

## Guardrails
- Maker ≠ checker on every goal.
- Security-critical change → full panel + red-team + audits/<date>-<goal>.md.
- Scope discipline: build only to the agreed surface; reject over-scope in review.
- No silent caps: log any bounded coverage to BOARD.md.
- Every merged goal appends "what changed & why" to handover.md.
- Confirm anything irreversible/outward-facing unless the user pre-authorized it.

## Self-unblock / escalation
Failed goal → write failure + next hypothesis to handover.md, reopen on BOARD.
After 3 failed passes on one goal → notify the user + park it (blocked) + move on.

## Stopping condition (definition of done)
<e.g. the core end-to-end journey passes AND the non-negotiable suites are green AND the
panel signs off the release. Then STOP building.>

## Resume protocol
New session reads, in order: project instructions → handover.md → BOARD.md → GOALS.md.

## What works here (evidence-backed heuristics — the loop MAY append; it may NEVER edit the guardrails)
- <e.g. integration tests must migrate the test DB before the parallel suite runs>
- <e.g. this suite is flaky under parallelism → confirm green with --no-file-parallelism>
```

---

## `GOALS.md` — the goal ladder

Each goal is thin, vertical, independently verifiable, in dependency order, with an
explicit acceptance criterion. The AC *is* the test.

```markdown
# Goals

## Slice <N> — <slice name / objective>

- [ ] **G<N>.1 <goal title>** — <one-line intent>.
      **AC:** <machine-checkable: which test passes / command is clean / journey completes>.
      Depends on: <none | G<N>.x>.
- [ ] **G<N>.2 <goal title>** — <intent>. **AC:** <...>. Depends on: G<N>.1.
      🔒 security-critical → strict panel + red-team + audit artifact.
- [ ] **G<N>.3 <optimization goal>** — <intent>. 📈 **metric AC:** <one metric + direction +
      threshold, e.g. "p95 latency ↓ ≥10% vs baseline">, measured with `<command>`; keep-or-revert.
- [ ] ...

### Slice <N> /goal (stop condition)
<what must all hold for the slice to be done — the sub-DoD for this slice>
```

Convention: `[ ]` open, `[x]` done. Mark `🔒` on goals that touch a security-critical area
so the loop knows to escalate the review automatically. Mark `📈` on optimization goals — the
loop runs those as metric-driven keep-or-revert experiments (logged to `EXPERIMENTS.md`), not
binary tests.

---

## `BOARD.md` — live state

The at-a-glance current position and the queue for newly-discovered work. Newest entry on
top. This is where nightly triage enqueues goals.

```markdown
# Board

- **<STATUS emoji> SLICE <N> — <name> — <one-line status>.** <2–4 sentences: what's done,
  what's in flight, the last commit, any decision locked, what's next.> Status: G<N>.1 ✅
  (`<sha>`), G<N>.2 🔨 in-progress, G<N>.3 ⛔ blocked (<why>).

## Open (triage queue)
- [ ] <newly discovered goal / failing test / UAT finding> — <source, note>

## Skipped / bounded (no silent caps)
- <what was sampled/skipped this run and why>
```

---

## `handover.md` — the narrative spine

The comprehension-debt guard and the self-unblock memory. 2–3 plain-English lines per
merged goal, plus any current failure + next hypothesis. Newest on top.

```markdown
# Handover

## Current focus
<what the loop is working on right now, and the immediate next goal>

## Last failure (if any) — self-unblock context
Goal: G<N>.x. Failed because <symptom>. Hypothesis for next pass: <what to try>.
Attempt count: <n>/3.

## Log (what changed & why)
✅ **G<N>.2 (`<sha>`)** — <what changed, in plain English> — <why it mattered / the
   decision behind it>. Panel: <verdict>. <evidence: N tests green>.
✅ **G<N>.1 (`<sha>`)** — <...>.
```

If a change can't be explained here in a few plain sentences, that's a stop signal — the
loop understands less than it thinks. Slow down rather than ship.

---

## `audits/<date>-<goal>.md` — security-critical evidence

Written whenever a goal changes a security-critical invariant. It's the durable record that
the change was actually attacked, not just asserted-safe.

```markdown
# Audit — <goal id> <short title> (<YYYY-MM-DD>)

## What changed
<the invariant touched and how>

## Threat model / what was attacked
<the concrete attacks the red-team attempted: cross-tenant read/write/join, privilege
escalation, auth bypass, gate circumvention, data-loss on a destructive migration, …>

## Evidence
<test names + results, adversarial queries run and their outputs, reviewer verdicts>

## Verdict
<GO / NO-GO, who confirmed (majority-must-confirm for security), residual risk, follow-ups>
```

---

## `EXPERIMENTS.md` — the keep-or-revert ledger (optimization goals only)

Append-only record for metric-driven goals, so a discarded experiment is never re-run. Read
it before proposing a new experiment; newest on top. Keep it committed if you want the
anti-repeat memory to survive a fresh clone.

```markdown
# Experiments — <metric name> (<direction, e.g. lower is better>)

Baseline: <value> @ `<sha>` — measured with `<command>` under <fixed budget, e.g. 5-min wall / 50k tok>.

| # | idea | result | Δ vs baseline | verdict | why |
|---|------|--------|---------------|---------|-----|
| 3 | <what was changed> | <value> | -8% | ✅ kept (`<sha>`) | <one line> |
| 2 | <...> | <value> | +2% | ↩️ reverted | worse — discarded the worktree |
| 1 | <...> | <value> | 0% | ↩️ reverted | no movement |
```

Rules: **never re-run a reverted idea** — dedup a new proposal against this table first. And
verify metrics maker ≠ checker — the checker re-measures from the baseline, never takes the
maker's number on faith.
