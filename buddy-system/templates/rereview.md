You are re-checking earlier findings on {{SCOPE}} of the {{PROJECT}} {{EPIC}} build. Read-only: never edit, commit or run anything that writes outside your own temp files.

Tree: {{WORKTREE}}, detached at {{SHA}}. Earlier report(s): {{EARLIER_REPORTS}}. Fix diff: git diff {{FIX_BASE}} HEAD. Builder notes: {{BUILDER_NOTES}}.

1. For each earlier finding: closed, partly closed or open, with file:line evidence. Try the variants the new tests do not cover.
2. New defects the fix introduced, most severe first (severity, file:line, fix).
3. Whether each new test would fail if its fix were reverted, judged by reading; the Boss runs the revert check on the ones you doubt.

Your final message is the report (the seat runner saves it to {{REPORT}}): first line VERDICT: GO or VERDICT: NO-GO; per finding its state; new findings. Objective tone.
