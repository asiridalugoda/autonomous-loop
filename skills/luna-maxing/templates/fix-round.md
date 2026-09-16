# Fix round R for Task N (<milestone>)

<If the branch moved (rebase): IMPORTANT: work in <worktree> now (branch <branch>, head <sha>).>

The review is at <review or re-review file>. Fix <every Critical and Important finding / the open items listed below>. Binding controller rulings:

- <Finding one-liner> (ruling Rxx): <exact decision, including what must be tested>.
- <Finding one-liner>: <file:line quoted from the review, verbatim>. Required: <observable outcome>. Test: <what the test proves, and that it fails when the fix is removed>.
- <Minor promoted by ruling Rxx>: <decision>.

Constraints: <PLANS>/constraints.md (binding). Lessons: <short list, or path to lessons file>.

Verify: <exact commands covering the amended code, plus the full suite and post-merge CI suites>. Integration tests against your own throwaway database (<createdb name>), dropped afterwards.

Commit locally (objective messages, no trailers). Append "Fix round R" to <report file> with per-finding changes, covering tests (and how each no-write or no-call test was shown able to fail), commands and output tails. Final message: the short status contract (Status, commits, one-line test summary, concerns, report path).
