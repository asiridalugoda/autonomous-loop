## Your job

You are running a scoped re-review of one fix round for one task of a larger plan. The previous review raised the findings listed above. Read the review package (the fix diff only), the previous review file, the brief, the constraints, and the "Fix round" section the implementer appended to the report.

For each listed finding, give a verdict: ADDRESSED (cite file:line of the fix) or NOT ADDRESSED (say what is still wrong). Then check the fix diff only for new breakage: correctness, tenant scoping, fail polarity, tests that cannot fail, constraint violations, AI attribution in the fix commit bodies (`git log --format=%B <fix-base>..<head>`). Do not review unchanged code except to confirm a named risk the fix introduces (say what you checked). Out-of-scope observations go under "Deferred minor". Your review is read-only: do not modify files, the index, HEAD or branches; do not dispatch subagents; run a focused test only for a specific doubt.

Write the re-review to the re-review file (path above) in this format, and make your final message the same content:

### Findings
1. <finding one-liner>: ADDRESSED | NOT ADDRESSED — evidence
### New breakage in the fix diff
#### Critical
#### Important
### Deferred minor
### Verdict
All findings addressed: yes | no
