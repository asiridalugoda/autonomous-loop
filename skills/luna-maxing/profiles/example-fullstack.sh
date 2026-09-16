# Full gate profile for example-app (multi-tenant SaaS monorepo: Go API + React/Vite web +
# Playwright e2e).
# Sourced by scripts/gates.sh; `run`, `$name`, and `$LUNA_WS` are in scope.
# Args: [--migrations] [--web] [--specs] [--e2e REGEX] [--it REGEX] [--ci-main]
# shellcheck shell=bash
# This profile is a sourced fragment; gates.sh supplies name and LUNA_WS.
# shellcheck disable=SC2154
# Before a web change, record the main typecheck diagnostics at:
#   (cd web && npx tsc --noEmit 2>&1 | grep "error TS" | sed -E 's/\([0-9]+,[0-9]+\)//' | sort) \
#     > "$LUNA_WS/example-app-web-tsc-main-errors.txt"

project_gates() {
  local migrations=0 web=0 specs=0 e2e="" it="" ci_main=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --migrations) migrations=1 ;;
      --web) web=1 ;;
      --specs) specs=1 ;;
      --e2e) e2e=$2; shift ;;
      --it) it=$2; shift ;;
      --ci-main) ci_main=1 ;;
    esac
    shift
  done

  # These are the ordinary pull-request checks; they run on every change in the API.
  run "api lint" 'cd api && go vet ./...'
  run "api build" 'cd api && go build ./...'
  run "api unit tests" 'cd api && go test ./...'

  if [ "$web" -eq 1 ]; then
    # The web checks are opt-in because the controller selects gates from the changed paths.
    run "web install" 'cd web && { [ -d node_modules ] || npm ci --no-audit --no-fund; }'
    run "web lint" 'cd web && npm run lint'
    # Compare file plus error code, not message text, because messages change as types grow.
    run "web typecheck (no new errors vs main, by file+code)" 'cd web && {
      test -f "$LUNA_WS/example-app-web-tsc-main-errors.txt"
      out=$(npx tsc --noEmit 2>&1); rc=$?
      printf "%s\n" "$out" | grep "error TS" | sed -E "s/\([0-9]+,[0-9]+\)//; s/(error TS[0-9]+):.*/\1/" | sort > "$LUNA_WS/$name-web-tsc-codes.txt" || true
      sed -E "s/(error TS[0-9]+):.*/\1/" "$LUNA_WS/example-app-web-tsc-main-errors.txt" | sort > "$LUNA_WS/example-app-web-tsc-main-codes.txt"
      if [ "$rc" -ne 0 ] && ! printf "%s\n" "$out" | grep -q "error TS"; then
        printf "%s\n" "$out"
        exit "$rc"
      fi
      comm -13 "$LUNA_WS/example-app-web-tsc-main-codes.txt" "$LUNA_WS/$name-web-tsc-codes.txt" | tee /dev/stderr | wc -l | grep -qx " *0"
    }'
    run "web build" 'cd web && npm run build'
    # The generator rewrites this tracked manifest; restore it so clean-tree measures the commit.
    run "restore web generated manifest" 'git checkout -- web/public/generated/manifest.json'
  fi

  if [ "$specs" -eq 1 ]; then
    # Listing browser specs rejects a selection that silently contains no tests.
    run "browser specs" 'cd e2e && out=$(npx playwright test --list 2>&1); rc=$?; printf "%s\n" "$out"; [ "$rc" -eq 0 ] && printf "%s\n" "$out" | grep -Eq "Total: [1-9][0-9]* test"'
  fi

  if [ "$migrations" -eq 1 ]; then
    # Migration replay uses its own empty database so schema checks never touch shared data.
    local migration_db migration_url
    migration_db="example_$(printf '%s' "$name" | tr '-' '_')_migration"
    migration_url="postgres://$USER@127.0.0.1:5432/$migration_db?sslmode=disable"
    run "migration database" "dropdb --if-exists $migration_db && createdb $migration_db"
    run "migration replay and schema verify" 'cd api && DATABASE_URL="'"$migration_url"'" make schema-verify'
    run "drop migration database" "dropdb --if-exists $migration_db"
  fi

  if [ -n "$it" ]; then
    # Integration tests can drop schema objects, so each gate gets a disposable named database.
    local itdb="example_${name//-/_}_it"
    local iturl="postgres://$USER@127.0.0.1:5432/$itdb?sslmode=disable"
    run "integration database" "dropdb --if-exists $itdb && createdb $itdb"
    # A skipped selection or an empty selection otherwise looks like a successful test command.
    run "integration $it" 'cd api && out=$(TEST_DATABASE_URL="'"$iturl"'" go test -tags integration -count=1 -v -run "'"$it"'" ./... 2>&1); rc=$?; printf "%s\n" "$out"; [ "$rc" -eq 0 ] && ! printf "%s\n" "$out" | grep -q -- "--- SKIP" && printf "%s\n" "$out" | grep -q -- "--- PASS"'
    run "drop integration database" "dropdb --if-exists $itdb"
  fi

  if [ -n "$e2e" ]; then
    # Targeted Playwright runs use a disposable database and reject an empty or skipped selection.
    local e2e_db e2e_url
    e2e_db="example_$(printf '%s' "$name" | tr '-' '_')_e2e"
    e2e_url="postgres://$USER@127.0.0.1:5432/$e2e_db?sslmode=disable"
    run "e2e database" "dropdb --if-exists $e2e_db && createdb $e2e_db"
    run "e2e $e2e" 'cd e2e && out=$(DATABASE_URL="'"$e2e_url"'" npx playwright test --grep "'"$e2e"'" 2>&1); rc=$?; printf "%s\n" "$out"; [ "$rc" -eq 0 ] && printf "%s\n" "$out" | grep -Eq "[1-9][0-9]* passed"'
    run "drop e2e database" "dropdb --if-exists $e2e_db"
  fi

  if [ "$ci_main" -eq 1 ]; then
    # These suites run only on push to main; PR CI does not exercise them before merge.
    local main_db="example_${name//-/_}_ci"
    local main_url="postgres://$USER@127.0.0.1:5432/$main_db?sslmode=disable"
    run "push-to-main database" "dropdb --if-exists $main_db && createdb $main_db"
    run "push-to-main integration" 'cd api && TEST_DATABASE_URL="'"$main_url"'" go test -tags integration -p 1 -count=1 ./...'
    run "push-to-main e2e" 'cd e2e && out=$(DATABASE_URL="'"$main_url"'" npx playwright test 2>&1); rc=$?; printf "%s\n" "$out"; [ "$rc" -eq 0 ] && printf "%s\n" "$out" | grep -Eq "[1-9][0-9]* passed"'
    run "drop push-to-main database" "dropdb --if-exists $main_db"
  fi
}
