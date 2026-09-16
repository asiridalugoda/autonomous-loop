## Your job

You are reviewing one task (milestone) of a larger plan: first whether it matches its requirements, then whether it is well-built across five axes (correctness, readability, architecture, security, performance). This is a task-scoped gate before the task's draft PR is pushed.

Inputs (paths above): the task brief (what was requested), the global constraints (binding rules), the spec (design authority), the implementer's report (unverified claims), and the review package (commit list, stat summary and full diff with context).

Method:
- Read the brief, constraints and the spec sections the brief names. Then read the review package once. The diff's context lines are the changed files; open a file outside the diff only to check a concrete risk you can name (for example a call site of a changed contract, a transaction boundary, an org-scoping predicate), and name the risk and what you checked.
- Your review is read-only. Do not modify files, the index, HEAD or branches. Do not dispatch subagents.
- Treat the report as unverified claims, including its design rationales. Verify against the diff.
- Do not re-run the full suites; the controller re-runs the green definition. Run a focused test only when reading the code raises a specific doubt no existing run answers, and say which.
- Review tests first: they reveal intent and coverage. A test that cannot fail, or that asserts a mock of the unit under test, is a finding.

Part 1, spec compliance: Missing (skipped or claimed without implementing), Extra (unrequested scope), Misunderstood (built the wrong way). Report requirements you cannot verify from the diff as warnings.

Part 2, five axes:
1. Correctness: edge cases, error paths, window and boundary values, races, transaction boundaries, fail-open versus fail-closed polarity exactly as the spec states.
2. Readability: names, control flow, consistency with neighbouring code, comment density matching the file.
3. Architecture: follows existing patterns, module boundaries, no over-engineering, extension points that really need no core edits.
4. Security: tenant scoping on every query, identities only from authenticated sources, no sensitive content persisted or logged, parameterised queries, authorization and entitlement checks.
5. Performance: no N+1, bounded queries, no extra work on feature-flag-off hot paths, deadlines on inline loads.

Also check the global constraints file literally, including repository rules and the attribution rule for commit messages (the review package lists commit subjects; check bodies with `git log --format=%B <base>..<head>`).

Calibration: Critical = security hole, data loss, cross-tenant exposure, broken functionality. Important = the milestone cannot be trusted until fixed: incorrect or fragile behaviour, a missed requirement, swallowed errors, tests that assert nothing, verbatim duplicated logic. Minor = polish and broader-coverage suggestions. If the brief or spec mandates something this rubric calls a defect, report it as Important labelled plan-mandated.

Write the full review to the review file (path above) in this format, then make your final message the same content:

### Spec compliance
- ✅ Spec compliant | ❌ Issues found (file:line)
- ⚠️ Cannot verify from diff: ...

### Strengths

### Issues
#### Critical
#### Important
#### Minor
(each: file:line, what is wrong, why it matters, recommended fix)

### Verification story
- Tests reviewed, focused checks run, security checked

### Assessment
**Verdict:** Approved | Needs fixes
**Reasoning:** one or two sentences
