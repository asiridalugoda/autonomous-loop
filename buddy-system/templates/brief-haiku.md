# Haiku lane {{LANE}}: {{TITLE}} ({{EPIC}} {{TASK}})

Read `{{SCRATCH}}/briefs/common.md` first; its rules bind you. This is an exact-change brief: make these changes and no others. If a file does not match what is described here, STOP and report the mismatch (file, line, what you found); do not improvise.

Start: `git checkout -B lane/{{EPIC_NUM}}-{{LANE}} {{BASE_SHA}}`.

## Changes, `{{path}}`
1. {{Exact edit: the function or line, the old text or shape, the new text or value.}}

## Tests
{{Each test by name, the file it lives in, and exactly what it asserts. For a regression: the red run against the base and the green run after.}}

## Gates (report exit codes)
{{Exact commands.}}

## Owned files
Exactly the files named above. Anything else: stop and report.

## Commit
One commit: `{{subject}}` with an objective body, via `{{COMMIT_CMD}}`.

## Report
`{{SCRATCH}}/reports/build/{{LANE}}.txt` in the common format. Return branch and head SHA.
