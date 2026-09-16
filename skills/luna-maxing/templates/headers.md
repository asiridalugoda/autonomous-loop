# Dispatch headers

A fresh-session prompt file = one header below + the matching body template (`implementer.md`, `reviewer.md`, `rereview.md`). A resumed-thread prompt (`fix-round.md`, `rebase-job.md`, `continue.md`) is complete on its own: no header, because the thread already holds the brief, constraints and body. A rebase job sent to a fresh session (the building thread is unavailable) adds the implementer header above `rebase-job.md`. Headers carry paths, never pasted content. Keep controller notes to interfaces and rulings the brief cannot know.

## Implementer (fresh session)

```
# Task N (milestone MN <name>) of <plan name>

Where this fits: <one line: stack position, base branch/PR, what runs in parallel and which files to keep minimal>.

- Task brief (read first; your requirements): <WS>/task-N-brief.md
- Global constraints (binding): <PLANS>/constraints.md
- Spec (design authority): <PLANS>/spec.md (<sections>)
- Working directory: <worktree> (branch <branch>, base <full sha>)
- Report file: <WS>/task-N-report.md

Controller notes:
- <interfaces produced by earlier tasks: names, signatures, tables, flags>
- <rulings that settle ambiguities, quoted from the ledger>

Lessons from earlier review rounds (apply up front):
- <accumulated lessons list, see lessons.md>
```

## Reviewer (fresh session, never the implementer's thread)

```
# Review: Task N (milestone MN <name>) of <plan name>

- Task brief: <WS>/task-N-brief.md
- Controller notes the implementer was given: <WS>/tN-notes.md   (if any)
- Global constraints: <PLANS>/constraints.md
- Spec: <PLANS>/spec.md (<sections>)
- Implementer report: <WS>/task-N-report.md
- Review package: <path printed by review-package>
- Repository checkout (read-only for you): <worktree>, base <sha>, head <sha>
- Review file (write your review here): <WS>/task-N-review.md

Controller context the brief cannot carry: <stack position, rulings that explain intentional absences, the named high-risk areas to check with care>.
```

## Scoped re-review (fresh session)

```
# Scoped re-review: Task N, fix round R

Findings under re-review (verbatim in <previous review file>), with these rulings (binding for verdicts):
- <ruling id: text>
Findings list:
1. <one-liner>
2. <one-liner>

Controller evidence you do not need to regenerate: <gates the controller already ran on this head>.

- Task brief / Global constraints / Implementer report (see "Fix round R") / Review package (fix diff) / Checkout (read-only), fix base, head / Re-review file
```
