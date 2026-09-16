# Rebase job: <branch> onto <new base>

Context: <what the new base changed (contract, files) and which commit conflicts first>.

Working directory: <worktree>. Checked-out branch <branch>, head <sha>, old base <old sha>.

Do:
1. `git rebase --onto <new base sha> <old base sha>` and resolve every conflict so both sides' behaviour survives exactly: <new base semantics that must survive> and <branch semantics that must survive>. Keep each commit's message. Minimal edits inside the commit being replayed.
2. After the rebase, reconcile where the two sides now disagree at the contract level (not textual conflicts): <examples>. Put that in ONE separate commit `fix(<scope>): <align X with Y>`.
3. Verify: <full gate commands>.

Constraints: <PLANS>/constraints.md (binding). Never push. No trailers.

Report: append "Rebase onto <base>" to <report file>: each conflict (file, how both semantics were preserved), the reconciliation commit contents, commands and output tails, final head SHA. Final message: Status (DONE | BLOCKED), head SHA, one-line test summary, concerns.
