# Seed lessons for Codex seats

Paste the relevant ones into every implementer and fix dispatch under "Lessons from earlier review rounds". Append new ones whenever a review finding reveals a class of mistake.

- A no-write, no-read or no-call assertion must be observable: record attempts before any best-effort error handling, and show the test fails when the guarded code is removed.
- A test must not compare an output against the same builder that produced it; pin at least one hand-written expected value.
- Changing a shared store, evaluator or handler contract: search every caller, including background jobs and system paths that pass an empty tenant.
- Tenant scoping comes before inspecting any stored document; a foreign resource returns the same 404 as a missing one.
- Distinguish "resolved absent" (403) from "could not resolve" (503); never let an outage look like a denial or an allow.
- Build-tagged or name-filtered test suites: name tests so the CI filter actually selects them, and prove it with `-list`.
- Destructive integration tests (DROP SCHEMA) use a throwaway database per seat, created and dropped by that seat.
- Tracked files rewritten by builds are restored before committing; never commit build output.
- Unpushed migrations may be edited in place; once pushed, any change takes a new slot.
- A feature flag off means zero extra work on the hot path; prove it with a test.
- Lock contention, deadlines and truncation are failure modes with explicit, stamped polarity, never silent skips.
- One-shot state (holds, tokens) is consumed only in the same successful flow that uses it.
- Background workers fence state updates with a lease or attempt token and treat zero rows affected as a lost claim.
