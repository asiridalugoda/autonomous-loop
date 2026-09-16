# Global constraints for example-app (bind every implementer and reviewer)

example-app is a multi-tenant SaaS monorepo: api/ is a Go service with SQL migrations in
api/migrations/; web/ is a React dashboard built with Vite and checked with tsc; e2e/ holds
Playwright specs. Pull-request CI runs lint, build, unit tests and typecheck; a separate
push-to-main workflow runs integration and e2e suites that pull-request CI never sees.

## Repository rules

- Toolchain setup: use the repository's pinned Go toolchain and the Node package manager named by
  the lockfile; do not substitute a global dependency version.
- Keep the API and web commands rooted in `api/` and `web/`; `e2e/` is the only browser-test tree.
- Git history carries no AI attribution of any kind: no AI co-author, generation marker, session
  link, or Codex or Claude attribution. Commit messages end with the body and have no trailers.
- Commit messages, code comments and docs are objective technical records: state what was wrong,
  what changed and why; do not address the reader or narrate the authoring process.
- Never edit an applied SQL migration; add the next numbered file under `api/migrations/` and
  verify the sequence before committing it.
- Migrations run transactionally, backfill before adding `NOT NULL`, and never use a concurrent
  index operation inside the migration transaction.
- Run the migration lock and verification commands after any migration or schema-lock change.
- Never push, open or edit a pull request, run a CI workflow, deploy, or touch a cloud resource;
  commit locally on the current branch only.
- Do not spawn subagents or reviewers from an implementer or reviewer seat.
- Do not commit credentials, session tokens, customer records, or local environment files.
- Integration and e2e gates use a throwaway database derived from the gate name; never point them
  at a shared development or production database.
- Playwright specs drive the browser through the UI; they do not call application HTTP endpoints
  as test helpers.
- The web build may rewrite `web/public/generated/manifest.json`; restore that tracked file before
  the end-of-gate clean-tree check.

## Product invariants

- Every read and write of tenant-owned state carries the authenticated tenant id; a colliding id
  from another tenant reads zero rows.
- A request for a foreign tenant's resource returns the same `404` as a missing resource.
- Subject identifiers come only from authenticated request context; an unauthenticated subject is
  inert and cannot create policy state.
- A failure to load policy state fails open with a stamped degradation; a matched enforcement
  threshold fails closed.
- An enforcement-path audit append is in the same transaction and fails closed with enforcement;
  an ungoverned allow may record best effort without changing the allow result.
- Feature flags default off and an off flag performs no policy, database, or audit work on the
  request hot path.
- Unknown policy kinds, event types, attributes, and actions are rejected during authoring; at
  runtime they contribute nothing and stamp `policy_unsupported`.
- Behaviour events persist bounded structured attributes only; prompts, responses, and other free
  text never enter the event store or application logs.
- Customer-facing copy uses `Example App`; internal project labels and test-only mode names never
  appear in visible copy.
- Error comparisons use file plus TypeScript error code; message text is not a stable baseline.
- A tenant boundary is checked before loading a stored document, so a foreign resource cannot be
  distinguished through a different error path.
- Background jobs preserve tenant scope and use an attempt or lease token before mutating state.

## Definition of local green (the controller re-runs these before any push)

- Pull-request CI steps pass: API lint, API build, API unit tests, web lint, web typecheck, and web
  build.
- `--migrations` runs the empty-database migration replay and schema verification checks.
- `--it REGEX` runs the selected integration tests against its own database and fails if any test
  skips or if no selected test reports `PASS`.
- `--e2e REGEX` runs the selected Playwright tests with the exact filter; a silent or empty run is
  not a pass.
- `--ci-main` runs the integration and e2e suites that the push-to-main workflow runs but PR CI
  does not see.
- Web typecheck compares the current diagnostics against the recorded main baseline by file and
  error code, and fails only when a new pair appears.
- Build-rewritten tracked files are restored before the final clean-tree check.
- The full gate run has a clean tree at start and end, no attribution, valid shell, and no private
  or local-only references.

Run the profile from the repository root with the required flags for the diff:

```sh
LUNA_WS=<workspace> \
LUNA_GATES_PROFILE=profiles/example-fullstack.sh \
  skills/luna-maxing/scripts/gates.sh <name> <worktree> <base sha> \
  [--migrations] [--web] [--e2e REGEX] [--it REGEX] [--ci-main]
```
