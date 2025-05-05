#!/usr/bin/env bash

set -euo pipefail

#  Förhindra direkt exekvering
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "❌ Denna fil är en modul och ska inte köras direkt."
  exit 1
fi

# Se till att denna file laddas in en och endast en gång
source "$(dirname "${BASH_SOURCE[0]}")/bash-guard.sh" || return
__bash_module_guard || return


file="$1"
total=0
passed=0
failed=0

source "$(dirname "$0")/tui-logging.sh"
source "$(dirname "$0")/tui-config.sh"

__strip_ansi() {
  sed -E 's/\x1B\[[0-9;]*[mK]//g'
}

__assert_equals() {
  local actual="$1"
  local expected="$2"
  local context="$3"
  ((total++))
  local clean=$(echo "$actual" | __strip_ansi)
  if [[ "$clean" == "$expected" ]]; then
    ((passed++))
    echo -e "${GREEN}✔︎${RESET} $context ⇒ \"$clean\""
  else
    ((failed++))
    echo -e "${RED}✘${RESET} $context"
    echo -e "   Förväntat: \"$expected\""
    echo -e "   Fick:      \"$clean\""
  fi
}

__assert_contains() {
  local actual="$1"
  local expected="$2"
  local context="$3"
  ((total++))
  if echo "$actual" | __strip_ansi | grep -q "$expected"; then
    ((passed++))
    echo -e "${GREEN}✔︎${RESET} $context innehåller \"$expected\""
  else
    ((failed++))
    echo -e "${RED}✘${RESET} $context"
    echo -e "   Förväntade innehålla: \"$expected\""
    echo -e "   Fick: $(echo "$actual" | __strip_ansi)"
  fi
}

__load_module_to_test() {
  local first_line
  first_line=$(head -n 1 "$file")
  if [[ "$first_line" =~ ^#@\ source:\ (.*) ]]; then
    local module="${BASH_REMATCH[1]}"
    [[ -f "$module" ]] && source "$module"
  fi
}

run_line_based_tests() {
  __load_module_to_test
  while IFS='|' read -r func input expected; do
    [[ -z "$func" || "$func" == \#* ]] && continue
    result=$($func $input 2>&1)
    if [[ "$expected" == "ERROR" ]]; then
      __assert_contains "$result" "ERROR" "$func \"$input\""
    else
      __assert_equals "$result" "$expected" "$func \"$input\""
    fi
  done < "$file"
}

run_block_based_tests() {
  local setup_block=""
  local teardown_block=""
  local in_setup=0
  local in_teardown=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "SETUP" ]]; then in_setup=1; setup_block=""; continue; fi
    if [[ "$line" == "TEARDOWN" ]]; then in_setup=0; in_teardown=1; teardown_block=""; continue; fi
    if [[ "$line" == "END" ]]; then in_teardown=0; continue; fi

    if (( in_setup )); then setup_block+="$line"$'\n'; continue; fi
    if (( in_teardown )); then teardown_block+="$line"$'\n'; continue; fi

    if [[ "$line" =~ => ]]; then
      cmd=$(echo "$line" | cut -d '=' -f1 | xargs)
      expected=$(echo "$line" | cut -d '>' -f2 | xargs)
      result=$(eval "$cmd" 2>&1 || true)
      if [[ "$expected" == "ERROR" ]]; then
        __assert_contains "$result" "ERROR" "$cmd"
      else
        __assert_contains "$result" "$expected" "$cmd"
      fi
    elif [[ -n "$line" && ! "$line" =~ ^# ]]; then
      eval "$line" >/dev/null 2>&1 && rc=0 || rc=$?
      ((total++))
      if [[ $rc -eq 0 ]]; then
        ((passed++))
        echo -e "${GREEN}✔︎${RESET} $line"
      else
        ((failed++))
        echo -e "${RED}✘${RESET} $line (kod $rc)"
      fi
    fi
  done < "$file"

  [[ -n "$setup_block" ]] && eval "$setup_block"
  [[ -n "$teardown_block" ]] && eval "$teardown_block"
}

# Start
echo "🧪 Kör testfall från: $file"

if grep -q '^#@ source:' "$file"; then
  run_line_based_tests
elif grep -q '^## test_target:' "$file"; then
  run_block_based_tests
else
  echo "❌ Okänt testformat"
  exit 1
fi

# Resultat
echo -e "\n📊 Totalt: $total | ${GREEN}✔︎ $passed${RESET} | ${RED}✘ $failed${RESET}"
[[ $failed -eq 0 ]]
