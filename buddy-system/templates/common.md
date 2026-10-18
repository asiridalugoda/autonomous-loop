# Common rules for every build lane (read first)

You are a builder seat on the {{PROJECT}} {{EPIC}} build. The plan is locked: {{PLAN}}. Build exactly your brief; if the brief and the code disagree, stop and report the fact rather than improvising.

## Environment
- {{TOOLCHAIN: PATH exports, module or package roots, how to install with the frozen lockfile}}
- {{SERVICES: how a seat gets its own database or service instance, e.g. `createdb <prefix>_<lane>_$(date +%s)` and the DSN to export; "none" if the project needs none}}
- Create your OWN scratch databases and service instances; never reuse or drop anyone else's, and drop only what you created. Integration harnesses that build and migrate their own scratch database need only a server DSN.
- Other agents share this machine. Touch only your worktree. Never write under `/tmp` directly; use your worktree or `$TMPDIR`.

## Hard rules
- Read {{READ_FIRST: the project instructions file and every instructions file covering the paths you touch}} before changing anything they cover.
- Regression tests: run the test against the UNFIXED code and capture the failure (for the reason the defect describes, not a compile error or a wrong selector), then fix and capture the pass. Report both, trimmed. A test you could not make fail is reported as such.
- Migrations: {{MIGRATION_RULES, e.g. forward-only, single-transaction safe, never edit an existing migration file, the numbering and lock checks to run; or "this project has none"}}
- An integration test never skips silently on an unprepared database: it migrates its own scratch database, and fails when it cannot.
- No new dependencies; do not touch {{LOCKFILES}}.
- Copy and comments: {{COPY_RULES, e.g. banned words, internal codenames that must not reach customer copy}}
- Machine limits: {{MACHINE_LIMITS}}. E2E: {{E2E}}.
- Never `git stash`, never push, never open PRs or issues, never touch branches other than your own, never edit CI configuration unless the brief owns it.

## Commits
Stage, then commit only with `{{COMMIT_CMD}}` (the profile's author and committer, refuses trailers). Messages are objective technical records: what was wrong, what changed, how it was verified. No mention of AI or any model. Check `git log --format='%ae %ce'` on your commits before reporting.

## Gates before reporting
{{LANE_GATES: build, lint or vet, unit tests, the integration packages you touched with pass and skip counts, formatters on touched files, the project's structural checks}}
- A failure outside your lane: show whether it is pre-existing by running it on the base commit.

## Report (your final message, and the report file the brief names)
1. Branch and commit SHAs, one line each with the subject.
2. `git diff --stat <base>...HEAD`.
3. Each regression test: name, red output, green output.
4. Each gate and its result, with pass and skip counts for integration runs.
5. Integration test names and packages, for the CI patterns.
6. Deviations, decisions you had to make, and anything left undone, each with the reason.
