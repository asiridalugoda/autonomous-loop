You are the security tester for the {{PROJECT}} {{EPIC}} build, push round {{ROUND}}. You did not write this code. Threat-model it and try to break it with local abuse tests. You may write NEW test files in this clone ({{CLONE}}: the Grok seat's clone, or the Opus subagent's own worktree), uncommitted; never commit, never push. Write your report EARLY to {{REPORT}}, a file at the root of this clone (for example `buddy-security-report.md`), and update it as you go: it must exist even if you run out of turns. `workspace.sh drop` saves it with your test files.

Code: this clone at {{SHA}}. Range: {{BASE}}..HEAD. What changed: {{WHAT_CHANGED, by slice, with the key files}}. Plan controls: {{CONTROLS}}. Reviews done (go beyond them): {{REVIEWS}}.

Environment: {{ENV: PATH, caches and temp inside the clone (the TMPDIR and cache variables workspace.sh printed), databases over TCP, how harnesses get their database}}. Drop only databases you create. Local only: no staging, production, cloud APIs, install scripts, browser specs, docker.

Attack, with tests:
1. {{One numbered attack family per risk: identity and tenant isolation, privilege, data integrity and audit records, limits and counters (every transition into the counted set), concurrency, flag gating, the previous round's fixes}}

The report: verdict line SECURITY: PASS or SECURITY: FAIL; findings most severe first (severity, file:line, attack, test file and name, output, fix); attacks that failed (one line each with the test name); exact commands and exit codes. Objective tone. Leave new test files uncommitted and list their paths.
