# Global constraints for <plan> (bind every implementer and reviewer)

## Repository rules (read the root instructions file and the one in every directory touched)
- Toolchain setup: <PATH exports, env>.
- Git history: <attribution rule from the user's and repo's instructions, e.g. no AI trailers of any kind>. Commit messages, comments and docs are objective technical records.
- Migrations: <numbering, never edit shipped ones, transaction rules, lock/verify commands>.
- Never push, never open or edit pull requests, never run CI workflows, never deploy, never touch cloud resources. Commit locally on the current branch only.
- Do not spawn subagents or reviewers.
- Test databases: <how e2e and integration tests get isolated databases; never shared ones>.

## Product invariants (from the spec and standing rules)
- <tenant isolation rule>
- <fail-open / fail-closed polarity rules>
- <flag defaults>
- <wording and naming bans in customer-facing copy>
- <data that must never be persisted or logged>

## Definition of local green (the controller re-runs these before any push)
- <PR CI steps>
- <suites that run only after merge (push-to-main workflows)>
- <baseline comparisons for pre-existing failures, compared structurally (file + code), not by message text>
