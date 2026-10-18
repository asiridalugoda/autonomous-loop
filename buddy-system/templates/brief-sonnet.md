# Sonnet lane {{LANE}}: {{TITLE}} ({{EPIC}} {{TASK}})

Read `{{SCRATCH}}/briefs/common.md` first; its rules bind you. Then read: {{PLAN_ROWS_AND_SOURCES}}.

Start: `git checkout -B lane/{{EPIC_NUM}}-{{LANE}} {{BASE_SHA}}`. Migration slot(s): {{SLOTS or "none"}}.

## Intent
{{One paragraph: what the slice achieves and the profile's release discipline (for example: behind a flag, off by default).}}

## Decisions (made; implement them)
1. {{Each decision the Boss has made, concrete enough that two builders would produce the same behaviour.}}

## Tests
- **Regression (red first):** {{the defect and the test that proves it}}
- **Acceptance:** {{the plan row's acceptance, as tests}}

## Gates (report exit codes)
{{The common gates plus lane-specific ones: named integration runs, migration checks, the e2e suites the profile requires for this area.}}

## Owned files
{{Exact paths. Name parallel lanes and the files they own, so this lane stays out of them.}}

## Commits
{{The commit list, each building on its own}}; use `{{COMMIT_CMD}}`.

## Report
`{{SCRATCH}}/reports/build/{{LANE}}.txt` in the common format. Return branch and head SHA.
