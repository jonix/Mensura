#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/bash-guard.sh" || return
__bash_module_guard || return
#echo "SOURCING FILE: ${BASH_SOURCE[0]}"

## ---
##@ task-doctor: Diagnostiserar miljö, verktyg och standardinställningar för TaskWarrior-verktyg
task-doctor() {
  echo "Kör TaskWarrior-systemdiagnos..."
  echo ""

  # 1. Kontrollera att externa verktyg finns
  echo "Kollar efter system verktyg"
  local tools=(task timew date grep sed)
  for cmd in "${tools[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "Verktyget '$cmd' saknas i PATH – vissa funktioner kommer inte fungera"
    else
      echo "'$cmd' finns"
    fi
  done
  echo ""

  # 2. Miljövariabler
  echo "Miljövariabler:"
  local vars=(
    TASK_DEFAULT_START
    TASK_DEFAULT_MEETING_LEN
    TASK_DEFAULT_BREAK
    TASK_DEFAULT_PROJECT
    TASK_DEFAULT_PRIO
  )
  for var in "${vars[@]}"; do
    local val="${!var}"
    if [[ -n "$val" ]]; then
      echo "✅ $var = \"$val\""
    else
      echo "ℹ️  $var inte satt – använder standard i skript"
    fi
  done
  echo

  # 3. Rekommenderade inställningar
  echo "📋 Rekommenderade exports att lägga i din shellprofil:"
  for var in "${vars[@]}"; do
    local val="${!var}"
    if [[ -z "$val" ]]; then
      case "$var" in
        TASK_DEFAULT_START)       val="08:00" ;;
        TASK_DEFAULT_MEETING_LEN) val="30min" ;;
        TASK_DEFAULT_BREAK)       val="15min" ;;
        TASK_DEFAULT_PROJECT)     val="todo" ;;
        TASK_DEFAULT_PRIO)        val="Mindre" ;;
      esac
      printf "  export %-25s=\"%s\"\n" "$var" "$val"
    fi
  done
}


## ---
##@ task-selftest: Verifiera att egna task aliases kan läsas in korrekt
task-selftest() {
  echo "Kör självtest..."

  if [[ ! -f "$__TASK_SCRIPT_PATH" ]]; then
    echo "__TASK_SCRIPT_PATH pekar inte på en existerande fil: $__TASK_SCRIPT_PATH"
    return 1
  fi

  echo "__TASK_SCRIPT_PATH verkar korrekt:"
  echo "   $__TASK_SCRIPT_PATH"

  echo "Testar task-help:"
  task-help || echo "task-help misslyckades"
}

## ---
##@ task-help: Liten hjälp på traven för alla task aliases
task-help() {
  echo "Tillgängliga kommandon:"
  grep '^##@' "${BASH_SOURCE[0]}" | sed -E 's/^##@[[:space:]]*//'
}
