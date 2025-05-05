#!/usr/bin/env bash
set -euo pipefail

TESTFILE="{$1:-}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Anropa alltid universal-runner
"$DIR/universal-runner.sh" "$TESTFILE"


function __is_time_or_offset_broken() {
  local input="$*"

  # Trimma och splitta på första mellanslag
  part1="${input%% *}"
  part2="${input#* }"
  [[ "$part1" == "$part2" ]] && part2=""

  # 1. Om det finns två delar: kontrollera om första är datum/datetime och andra en offset
  if [[ -n "$part2" ]]; then
    if [[ "$part1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{2}:[0-9]{2})?$ ]] &&
       [[ "$part2" =~ ^\+?([0-9]+(h|hr|hour|tim|timme|timmar)|[0-9]+(m|min|minuter|minutes)){1,2}$ ]]; then
      echo "OFFSET"
      return 0
    fi
  fi

  # 2. Datum (med eller utan tid) + offset, inklusive +1h30m
  if [[ "$input" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{2}:[0-9]{2})?[[:space:]]+\+?([0-9]+(h|hr|hour|tim|timme|timmar)|[0-9]+(m|min|minuter|minutes)){1,2}$ ]]; then
    echo "OFFSET"
    return 0
  fi

  # 3. Tidformat (HH:MM, HH.MM, HHMM) + offset
  if [[ "$input" =~ ^([0-9]{1,2}:[0-9]{2}|[0-9]{3,4}|[0-9]{1,2}\.[0-9]{2})[[:space:]]+\+?([0-9]+(h|hr|hour|tim|timme|timmar)|[0-9]+(m|min|minuter|minutes)){1,2}$ ]]; then
    echo "OFFSET"
    return 0
  fi

  # 4. Endast tid: HH:MM, HH.MM
  if [[ "$input" =~ ^([0-9]{1,2}:[0-9]{2}|[0-9]{1,2}\.[0-9]{2})$ ]]; then
    echo "TIME"
    return 0
  fi

  # 5. 4-siffrig tid: HHMM
  if [[ "$input" =~ ^[0-9]{4}$ ]]; then
    echo "TIME"
    return 0
  fi

  # 6. Offset enbart: t.ex. +1h30m, 30m, 1h
  if [[ "$input" =~ ^\+?([0-9]+(h|hr|hour|tim|timme|timmar)|[0-9]+(m|min|minuter|minutes)){1,2}$ ]]; then
    echo "OFFSET"
    return 0
  fi

  # 7. Enbart siffror: t.ex. "30" = 30 minuter
  if [[ "$input" =~ ^[0-9]{1,3}$ ]]; then
    echo "OFFSET"
    return 0
  fi

  # 8. Fel
  __log_error "ERROR: kan inte tolka tidsangivelsen \"$input\""
  return 1
}
