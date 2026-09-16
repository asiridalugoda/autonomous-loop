# Luna-maxing reference

## Setup (once per plan)

1. **Codex readiness.** `codex --version`; confirm the model and effort exist in `~/.codex/models_cache.json` (`slug` and `supported_reasoning_levels`); smoke test:
   `codex exec -m gpt-5.6-luna -c 'model_reasoning_effort="max"' --skip-git-repo-check --ephemeral -s read-only "Reply with exactly: LUNA_OK"`.
2. **Spec and plan.** Use a git-ignored plans directory in the controller's worktree (check `.gitignore`; `.superpowers/` is the default): `.superpowers/plans/spec-<id>.md` (the source issue body or design doc, verbatim), `.superpowers/plans/constraints-<id>.md`, `.superpowers/plans/<id>-<slug>.md` (the plan). Worktrees: `/private/tmp/<project>-<id>-<milestone>`. Branches: `feat/<slug>-<milestone>-<id>`, where `<milestone>` is the lowercase milestone label used in the plan heading (`m0`, `m3`, `a`), never the task index. The plan has one `## Task N: <milestone> (branch <name>, base <task or main>)` section per PR: scope, build list, acceptance (local), and which acceptance items need a deployed environment (these become open gates, never faked).
3. **Workspace and ledger.** Resolve the SDD workspace with `superpowers:subagent-driven-development`'s `scripts/sdd-workspace PLAN`; extract briefs with `scripts/task-brief PLAN N`; review packages with `scripts/review-package PLAN BASE HEAD`. Locate the scripts with
   `ls -d ~/.claude/plugins/cache/claude-plugins-official/superpowers/*/skills/subagent-driven-development/scripts | tail -1`.
   Ledger `progress.md`: first line names the plan; preflight scan table (task pairs that share files or interfaces); numbered rulings `Rn Ruling: <decision> — <why> — <cost if wrong>`; progress lines per dispatch, fix round and completion, including Codex thread ids and commit ranges.
4. **Constraints file** from `templates/constraints.md` (worked example: `examples/constraints-example-saas.md`). Transcribe: every "NEVER/ALWAYS" rule from the root and touched-directory instruction files; the user's global rules on attribution and writing; standing memories that constrain output (naming bans, wording bans, data that must not persist); invariants stated in the spec; the definition of local green.
5. **Baselines on main.** Run the full gate profile on the untouched base and record pre-existing failures (for type checkers, save the error set so later comparison is by file + error code).
6. **Gate profile** in `profiles/<project>.sh`: PR CI steps plus suites that only run after merge (read every workflow's triggers; push-to-main-only jobs are invisible to PR CI but break main after merge).

## Per-task loop

1. `git worktree add -b <branch> /private/tmp/<project>-<task> <base ref>`; record BASE (full sha).
2. Compose the implementer prompt: header (`templates/headers.md`) + `templates/implementer.md`. Dispatch in the background:
   `LUNA_WS=<ws> scripts/dispatch.sh tN-impl <worktree> <ws>/tN-dispatch.md`. Record the thread id from the first jsonl line.
3. On completion read only the short final message and `git log --oneline BASE..HEAD`, `git status --short`, `git diff --stat`. Check new tests are selected by CI filters and build tags.
4. In parallel: dispatch the reviewer (fresh session; header + `templates/reviewer.md`, review package path) and run `scripts/gates.sh` with the project profile, choosing flags from the diff (`git diff --stat BASE..HEAD`), not from the task title:

   | Diff touches | Gate flags that become mandatory (example-fullstack profile names) |
   |---|---|
   | any backend code | full suite plus every post-merge-only suite (`--ci-main`) |
   | migrations or schema lock | `--migrations` |
   | new or changed integration-tagged tests | `--it <exact test names>` |
   | new or changed e2e tests | `--e2e <exact test names>` |
   | dashboard or frontend | `--web` |
   | browser specs | `--specs` |

   Before the push, the final gate run on the exact head uses the union of every flag the task ever needed. Confirm targeted e2e or integration tests really ran (a 1 s pass, `no tests to run`, or `--- SKIP` means they did not).
5. Findings: rule on anything that is a design question or conflicts with the plan (ledger), promote Minors that sit on a hot path or evidence surface, then resume the implementer thread with `templates/fix-round.md` (`dispatch.sh --resume <thread>`). Findings are quoted verbatim with file:line.
6. Scoped re-review (fresh session; header + `templates/rereview.md`) over `review-package PLAN FIX_BASE HEAD`, plus gates. Loop until all findings ADDRESSED and no new Critical/Important breakage (cap five rounds, then adjudicate each open finding in the ledger).
7. Complete: gates green on the exact head, review clean, clean tree. Push; open a DRAFT PR with base = previous task's branch; body per the user's PR-writing rules (objective, verification listed, open gates listed, pre-existing behaviour changes called out). Ledger `Task N: complete (commits a..b, review clean) — pushed, draft PR #x`.

## Parallel lanes and stacking

- A stack is dependency order, not milestone numbering. A task that depends only on an earlier task may move ahead of a larger one (record the reorder as a ruling and state it in the PR body).
- Run at most two Codex seats at once, each in its own worktree. Good pairs: a task and an independent sibling off the same base; a reviewer and an implementer on different branches.
- Independent lanes rebase onto the finished predecessor. Try `git rebase --onto <new base> <old base>` yourself; on conflict `git rebase --abort` and dispatch `templates/rebase-job.md` to a Codex seat (resume the thread that built the branch). Verify with `git range-diff old_base..old_head new_base..new_head` (commits marked `!` changed), a scoped Codex review of the resolution and any reconciliation commit, and full gates.
- Keep the stack linear. A task depending on two siblings goes on top of whichever lands last, after that one is rebased onto the other; never merge commits into a stack branch.
- A branch that already has a draft PR and gets rebased: confirm the PR is still open and unmerged (`gh pr view <n> --json state`), gate the rebased head, `git push --force-with-lease`, then `gh pr edit <n> --base <new base branch>` and note the rebase in the PR description. Never open a second PR for the same task.
- Never rebase a worktree while a reviewer is reading it. Rebase a copy (a new branch in another worktree), then move the original branch pointer with `git reset --hard <verified tip>` only when that branch is unpushed and its worktree is clean.
- Split a large UI task into phases on one branch when half of it depends on a sibling still in progress; ship it as one PR.

## Failure playbook

| Signal | Action |
|---|---|
| `USAGE_LIMIT ... RESET_AT=h:mm PM` from dispatch (exit 75) | Ledger it; run `scripts/wait-codex-reset.sh "<reset>"` in the background; meanwhile run gates and draft next dispatch notes. On `CODEX_READY`: a **review or re-review** seat is re-dispatched fresh with the same prompt, marked as a fresh attempt (reviews write their file only at the end). An **implementer, fixer or rebase** seat is resumed on its thread (`--resume`) with `templates/continue.md` when the worktree has new commits or uncommitted changes or a rebase is in progress; with no trace of work, re-dispatch the original prompt. Do not substitute another model for build or review work. |
| `Selected model is at capacity` | dispatch.sh retries automatically; exit 76 means wait and retry later. |
| Seat finished but no commits / report | Check the jsonl tail for errors; if work is partial, resume the thread with a completion prompt. |
| Rebase conflict | Abort; Codex rebase job; range-diff review; gates. |
| Gate fails on a gate defect (wrong path, message-text comparison, missing build tag) | Fix the gate script, record the defect in the ledger, rerun; never weaken a real check. |
| Gate fails on code | Fix round to the implementer thread with the failing command and output tail. |
| Build rewrites a tracked file | Restore it inside the gate before the end-of-gate clean-tree check. |
| Local end-to-end run needs an app stack | Isolated database, non-default ports, scratch proxy config outside the repo; never stop or reuse a stack the user is running; tear down only what was started. |
| Reviewer finding conflicts with the plan | Rule with the spec as authority; ledger it; carry the ruling into the fix dispatch and the re-review header. |
| A fix changes behaviour that already exists on main | Allowed when it is the correct fix; call it out in the PR body; surface security-relevant pre-existing gaps to the user as a decision (split out or keep in the stack). |

## Status reporting to the user

Answer "status" questions from live state (`git log`, jsonl event counts, `gh pr list`), not memory: per-task table (done / in review / building / not started), what the current reviews found, blockers (usage limits, capacity), open gates, and any decision waiting on the user. Percentages: give the count-based number and label any effort-weighted estimate as an estimate.
