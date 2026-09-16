# Gate profile for the public autonomous-loop skill repository.
# Sourced by scripts/gates.sh; run, name, and LUNA_WS are supplied by that caller.
# The source skill is optional: a clone without it skips only the fidelity comparison.

# shellcheck shell=bash
# This profile is a sourced fragment; the caller provides run, name, and LUNA_WS.
# shellcheck disable=SC2154

source_skill=$(printenv LUNA_SOURCE_SKILL 2>/dev/null || true)

check_skill_frontmatter() {
  local file first closing name_value description_data description_length description_has_text
  local expected_name
  local files bad=0
  files=$(git ls-files -- '*SKILL.md')
  if [ -z "$files" ]; then
    echo "no tracked SKILL.md files"
    return 1
  fi
  for file in $files; do
    first=$(sed -n '1p' "$file")
    closing=$(awk 'NR > 1 && $0 == "---" { print NR; exit }' "$file")
    if [ "$first" != "---" ] || [ -z "$closing" ]; then
      echo "$file: missing frontmatter delimiters"
      bad=1
      continue
    fi
    name_value=$(awk -v end="$closing" 'NR > 1 && NR < end && /^name:[[:space:]]*/ { sub(/^name:[[:space:]]*/, ""); print; exit }' "$file")
    description_data=$(awk -v end="$closing" '
      function add_text(text, compact) {
        value=value text
        compact=text
        gsub(/[[:space:]]/, "", compact)
        if (compact != "") has_text=1
      }
      function add_plain(text) {
        if ((text ~ /^".*"$/) || (text ~ /^'"'"'.*'"'"'$/)) {
          text=substr(text, 2, length(text) - 2)
        }
        add_text(text)
      }
      function add_block(text) {
        if (block_seen) value=value " "
        add_text(text)
        block_seen=1
      }
      NR > 1 && NR < end {
        if (!found) {
          if ($0 ~ /^description:[[:space:]]*/) {
            raw=$0
            sub(/^description:[[:space:]]*/, "", raw)
            found=1
            if (raw ~ /^[>|][-+]?[1-9]?[[:space:]]*$/) {
              block=1
            } else {
              add_plain(raw)
            }
          }
          next
        }
        if (block) {
          if ($0 == "" || $0 ~ /^[[:space:]]+/) {
            line=$0
            sub(/^[[:space:]]+/, "", line)
            add_block(line)
          } else {
            block=0
          }
        }
      }
      END {
        if (found) printf "%d\t%d\n", length(value), has_text + 0
        else print "MISSING"
      }
    ' "$file")
    if [ "$description_data" = "MISSING" ]; then
      description_length=""
      description_has_text=""
    else
      description_length=${description_data%%$'\t'*}
      description_has_text=${description_data#*$'\t'}
    fi
    expected_name=$(basename "$(dirname "$file")")
    # The root checkout can be any worktree path; its logical skill directory is fixed by the repo.
    if [ "$file" = "SKILL.md" ]; then expected_name=autonomous-loop; fi
    if [ -z "$name_value" ]; then
      echo "$file: missing name"
      bad=1
    elif [ "$name_value" != "$expected_name" ]; then
      echo "$file: name '$name_value' differs from '$expected_name'"
      bad=1
    fi
    if [ -z "$description_length" ]; then
      echo "$file: missing description"
      bad=1
    elif [ "$description_has_text" -eq 0 ]; then
      echo "$file: description is empty or whitespace-only"
      bad=1
    elif [ "$description_length" -ge 1024 ]; then
      echo "$file: description is $description_length characters; limit is below 1024"
      bad=1
    fi
  done
  return "$bad"
}

check_markdown_links() {
  local file links link target directory target_path resolved relative repo_root bad=0
  repo_root=$(git rev-parse --show-toplevel) || {
    echo "markdown link check cannot determine repository root"
    return 1
  }
  repo_root=$(cd -P "$repo_root" && pwd -P) || {
    echo "markdown link check cannot canonicalize repository root"
    return 1
  }
  for file in $(git ls-files -- '*.md'); do
    if ! links=$(perl -ne 'while (/\]\(\s*(?:<([^>]+)>|([^\s)]+))/g) { print defined($1) ? "$1\n" : "$2\n"; } while (/^\s{0,3}\[[^\]]+\]:\s*(?:<([^>]+)>|([^\s]+))/gm) { print defined($1) ? "$1\n" : "$2\n"; }' "$file"); then
      echo "$file: markdown link parser failed (Perl unavailable or parser exited non-zero)"
      return 1
    fi
    while IFS= read -r link; do
      case "$link" in
        ""|\#*|http://*|https://*|mailto:*) continue ;;
      esac
      target=${link%%#*}
      target=$(printf '%s\n' "$target" | sed 's/[?].*$//')
      [ -n "$target" ] || continue
      case "$target" in
        /*)
          echo "$file: absolute link target is not allowed $link"
          bad=1
          continue
          ;;
      esac
      directory=$(dirname "$file")
      target_path="$repo_root/$directory/$target"
      if ! resolved=$(perl -MCwd=abs_path -e 'my $path=abs_path(shift); print $path if defined $path' "$target_path"); then
        echo "$file: link path resolver failed for $link"
        bad=1
        continue
      fi
      if [ -z "$resolved" ]; then
        echo "$file: missing relative link target $link"
        bad=1
        continue
      fi
      case "$resolved" in
        "$repo_root"/*) ;;
        *)
          echo "$file: relative link target resolves outside repository $link"
          bad=1
          continue
          ;;
      esac
      relative=${resolved#"$repo_root"/}
      if ! git ls-files --error-unmatch -- "$relative" >/dev/null 2>&1; then
        echo "$file: relative link target is not tracked $link"
        bad=1
      fi
    done <<< "$links"
  done
  return "$bad"
}

check_shell_syntax() {
  local file bad=0
  for file in $(git ls-files -- '*.sh'); do
    if ! bash -n "$file"; then bad=1; fi
  done
  return "$bad"
}

check_shellcheck() {
  local file bad=0
  for file in $(git ls-files -- '*.sh'); do
    case "$file" in
      skills/luna-maxing/scripts/gates.sh)
        # The vendored command-string runner must retain eval; fidelity forbids annotating it.
        if ! shellcheck --shell=bash --severity=warning --exclude=SC2294 "$file"; then bad=1; fi
        ;;
      skills/luna-maxing/scripts/wait-codex-reset.sh)
        # The fixed retry-count loop documents attempts but needs no loop variable.
        if ! shellcheck --shell=bash --severity=warning --exclude=SC2034 "$file"; then bad=1; fi
        ;;
      *)
        if ! shellcheck --shell=bash --severity=warning "$file"; then bad=1; fi
        ;;
    esac
  done
  return "$bad"
}

check_script_permissions() {
  local entries
  entries=$(git ls-files -s -- 'skills/*/scripts/*.sh')
  if [ -z "$entries" ]; then
    echo "no vendored scripts found"
    return 1
  fi
  printf '%s\n' "$entries" | awk '$1 != "100755" { print "wrong mode: " $0; bad=1 } END { exit bad }'
}

check_no_private_references() {
  local encoded term
  local bad=0
  # Keep this hex-encoded ban list in the clone-local gate so no private source checkout is needed.
  for encoded in \
    68656c69786172 \
    6f6e797831 \
    6265617274726170 \
    70726f647563742031 \
    70726f647563742032 \
    6d6f64652031 \
    6d6f64652032 \
    68656c697861725f6265686176696f725f \
    6465762d746f6b656e2d756e73616665 \
    657069632023393634 \
    657069632d393634 \
    23393634 \
    2f75736572732f; do
    term=$(printf '%s' "$encoded" | perl -pe '$_=pack("H*", $_)')
    if git grep --cached -n -i -e "$term" -- . ':(exclude)skills/luna-maxing/profiles/autonomous-loop.sh'; then
      bad=1
    fi
  done
  return "$bad"
}

check_version_agreement() {
  local root_version readme_version luna_version
  root_version=$(awk '
    NR > 1 && $0 == "---" { exit }
    /^version:[[:space:]]*/ { sub(/^version:[[:space:]]*/, ""); print; exit }
  ' SKILL.md)
  readme_version=$(grep -Eo 'v[0-9]+\.[0-9]+\.[0-9]+' README.md | head -1 | sed 's/^v//')
  luna_version=$(awk '
    NR > 1 && $0 == "---" { exit }
    /^version:[[:space:]]*/ { sub(/^version:[[:space:]]*/, ""); print; exit }
  ' skills/luna-maxing/SKILL.md)
  test -n "$root_version" || { echo "root version missing"; return 1; }
  test -n "$luna_version" || { echo "Luna-maxing version missing"; return 1; }
  if [ "$root_version" != "$readme_version" ]; then
    echo "root version $root_version disagrees with README version $readme_version"
    return 1
  fi
}

check_vendor_fidelity() {
  local source="$source_skill"
  local file expected
  for file in scripts/dispatch.sh scripts/gates.sh scripts/wait-codex-reset.sh \
    templates/headers.md templates/implementer.md templates/reviewer.md templates/rereview.md \
    templates/fix-round.md templates/rebase-job.md templates/continue.md templates/constraints.md \
    templates/lessons.md profiles/example-minimal.sh; do
    diff -u "$source/$file" "skills/luna-maxing/$file" || return 1
  done

  expected="$LUNA_WS/luna-skill.expected"
  awk 'NR == 3 { print; print "license: Apache-2.0"; print "version: 1.0.0"; next } { print }' \
    "$source/SKILL.md" > "$expected"
  perl -0pi -e 's#(\| Constraints file .*?\x60examples/)[^\x60]+#\1constraints-example-saas.md#; s#\| Gate profiles \|[^\n]*#| Gate profiles | \x60profiles/example-fullstack.sh\x60 (full example), \x60profiles/example-minimal.sh\x60 (template), \x60profiles/autonomous-loop.sh\x60 (repository gate) |#g' "$expected"
  diff -u "$expected" skills/luna-maxing/SKILL.md || return 1

  expected="$LUNA_WS/luna-reference.expected"
  cp "$source/reference.md" "$expected"
  perl -0pi -e 's#(\(worked example: \x60examples/)[^\x60]+#\1constraints-example-saas.md#; s/\([^)]* profile names\)/(example-fullstack profile names)/g; s/--dashboard/--web/g' "$expected"
  diff -u "$expected" skills/luna-maxing/reference.md || return 1
}

project_gates() {
  run "skill frontmatter" 'check_skill_frontmatter'
  run "markdown links" 'check_markdown_links'
  run "shell syntax" 'check_shell_syntax'
  if command -v shellcheck >/dev/null 2>&1; then
    run "shellcheck" 'check_shellcheck'
  else
    echo "SKIP shellcheck (shellcheck is not installed)"
  fi
  run "script permissions" 'check_script_permissions'
  run "no private references" 'check_no_private_references'
  run "version agreement" 'check_version_agreement'
  if [ -n "$source_skill" ] && [ -d "$source_skill" ]; then
    run "vendor fidelity" 'check_vendor_fidelity'
  else
    echo "SKIP vendor fidelity (LUNA_SOURCE_SKILL is unset or missing)"
  fi
}
