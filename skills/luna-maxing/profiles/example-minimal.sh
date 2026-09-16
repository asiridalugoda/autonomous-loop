# Minimal gate profile template. Copy, rename after the project, and replace the commands
# with the repository's real PR CI steps PLUS any suites that only run after merge.
# Sourced by scripts/gates.sh; `run LABEL 'COMMAND'` evaluates COMMAND in the worktree root.

project_gates() {
  local extra=""
  while [ $# -gt 0 ]; do
    case "$1" in --e2e) extra=$2; shift ;; esac
    shift
  done
  run "build" 'make build'
  run "lint" 'make lint'
  run "unit tests" 'make test'
  if [ -n "$extra" ]; then run "targeted e2e $extra" 'make e2e RUN="'"$extra"'"'; fi
}
