#!/usr/bin/env sh

# Se till att denna fil laddas in en och endast en gång
source "$(dirname "${BASH_SOURCE[0]}")/bash-guard.sh" || return
__bash_module_guard || return
#echo "SOURCING FILE: ${BASH_SOURCE[0]}"

set -euo pipefail

TESTFILE="$1"
source_file=""
target_func=""

echo "🧪 Kör testfall från: $TESTFILE"

# Hämta vilken funktion som ska testas (valfritt)
target_func=$(grep '^## test_target:' "$TESTFILE" | cut -d ':' -f2- | xargs)

# Temporär arbetssession
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Inkludera testtarget om önskat
if [[ -n "$target_func" ]]; then
  for f in task-*.sh normalize-*.sh *.lib.sh; do
    [[ -f "$f" ]] && source "$f"
  done
fi

# Init counters
total=0
pass=0
fail=0
in_setup=0
in_teardown=0
script_block=""

run_block() {
  local block="$1"
  [[ -z "$block" ]] && return 0
  bash -c "$block"
}

while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" =~ ^SETUP$ ]]; then
    in_setup=1
    script_block=""
    continue
  elif [[ "$line" =~ ^TEARDOWN$ ]]; then
    in_setup=0
    in_teardown=1
    run_block "$script_block"
    script_block=""
    continue
  elif [[ "$line" =~ ^END$ ]]; then
    in_teardown=0
    run_block "$script_block"
    script_block=""
    continue
  elif [[ "$in_setup" -eq 1 || "$in_teardown" -eq 1 ]]; then
    script_block+="$line"$'\n'
    continue
  fi

  if [[ "$line" =~ => ]]; then
    ((total++))
    IFS='=>' read -r cmd expected <<< "$line"
    cmd=$(echo "$cmd" | xargs)
    expected=$(echo "$expected" | xargs)

    result=$((eval "$cmd") 2>&1)
    if [[ "$result" == "$expected" || "$expected" == "*" || "$result" =~ $expected ]]; then
      echo "✔︎ $cmd"
      ((pass++))
    else
      echo "✘ $cmd"
      echo "   Förväntat: $expected"
      echo "   Fick:      $result"
      ((fail++))
    fi
  elif [[ -n "$line" && ! "$line" =~ ^# ]]; then
    ((total++))
    eval "$line" >/dev/null 2>&1 && status=0 || status=$?
    if [[ "$status" == "0" ]]; then
      echo "✔︎ $line"
      ((pass++))
    else
      echo "✘ $line (returkod $status)"
      ((fail++))
    fi
  fi
done < "$TESTFILE"

echo ""
echo "📊 Totalt: $total | ✔︎ $pass | ✘ $fail"
exit "$fail"
