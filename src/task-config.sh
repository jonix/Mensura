#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/bash-guard.sh" || return
__bash_module_guard || return
#echo "SOURCING FILE: ${BASH_SOURCE[0]}"


#######
## TaskWarrior + TimeWarrior konfigurationshjälp
## Centraliserar hantering av miljövariabler och defaultvärden
#########


# Hämta värde från env, eller använd fallback från __task_get_default
# Syntax: sod=$(__task_get_config "TASK_START_OF_DAY")
__task_get_config() {
  local var="$1"
  local fallback=$(__task_get_default "$var") || return 1
  echo "${!var:-$fallback}"
}

# Centrala standardvärden
__task_get_default() {
  case "$1" in
    TASK_START_OF_DAY)     echo "08:00" ;;
    TASK_BREAK_LENGTH)     echo "15min" ;;
    TASK_LUNCH_LENGTH)     echo "60min" ;;
    #---"
    TASK_DEFAULT_PRIO)     echo "Mindre" ;;
    TASK_DEFAULT_PROJECT)  echo "todo"   ;;
    #---#
    TASK_MEETING_LENGTH)   echo "45min"    ;; # Kan sättas direkt vid skapande av mötes kallelsen
    TASK_MEETING_PROJECT)  echo "möte"     ;; # Namn på mötes projektet
    TASK_MEETING_TAGS)     echo "+meeting" ;; # Kan sätta upp flera taggar med +namn1 +namn2
    TASK_MEETING_PRIO)     echo "Mindre"   ;; # Sätter på Mindre, för att inte ta skrikig plats i Task vyn

    #---#
    TASK_BRAND_PROJECT)    echo "utredning" ;;
    TASK_BRAND_PRIO)       echo "Kritiskt"  ;;
    TASK_BRAND_TAGS)       echo "+brand"    ;;
    #---#
    *)
      echo "Okänd default för $1" >&2
      return 1
      ;;
  esac
}


## ---
##@ task-defaults: Visar aktiva och standardvärden för TASK_* miljövariabler
task-defaults() {
  echo "📋 Aktiva TaskWarrior-standardvärden (från miljövariabler):"
  echo ""

  local vars=(
    TASK_START_OF_DAY
    TASK_BREAK_LENGTH
    TASK_LUNCH_BREAK
    TASK_DEFAULT_PRIO
    TASK_DEFAULT_PROJECT
    TASK_MEETING_LENGTH
    TASK_MEETING_PROJECT
    TASK_MEETING_TAGS
    TASK_MEETING_PRIO
    TASK_BRAND_PROJECT
    TASK_BRAND_PRIO
    TASK_BRAND_TAGS
  )

  for var in "${vars[@]}"; do
    local val="$(__task_get_config "$var")"
    local fallback="(standard)"
    [[ -n "${!var}" ]] && fallback="(användarsatt)"
    printf "  %-25s → %-10s %s\n" "$var" "$val" "$fallback"
  done
}

## ---
##@ task-doctor: Diagnostiserar miljö, verktyg och rekommenderade exports
task-doctor() {
  echo "🩺 Kör TaskWarrior-systemdiagnos..."
  echo

  # 1. Kontrollera att verktyg finns
  local tools=(task timew date grep sed)
  for cmd in "${tools[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "❌ Verktyget '$cmd' saknas i PATH – vissa funktioner kommer inte fungera"
    else
      echo "✅ '$cmd' finns"
    fi
  done
  echo

  # 2. Miljövariabler
  echo "🧩 Miljövariabler:"
  local vars=(
    TASK_START_OF_DAY
    TASK_MEETING_LENGTH
    TASK_BREAK_LENGTH
    TASK_LUNCH_LENGTH
    TASK_DEFAULT_PROJECT
    TASK_DEFAULT_PRIO
  )
  for var in "${vars[@]}"; do
    local val="$(__task_get_config "$var")"
    if [[ -n "${!var}" ]]; then
      echo "✅ $var = \"$val\""
    else
      echo "ℹ️  $var inte satt – använder standard: \"$val\""
    fi
  done
  echo

  # 3. Rekommenderade shell-inställningar
  echo "📋 För att permanent sätta dessa, lägg till i ~/.bashrc:"
  for var in "${vars[@]}"; do
    if [[ -z "${!var}" ]]; then
      local val="$(__task_get_default "$var")"
      printf "  export %-25s=\"%s\"\n" "$var" "$val"
    fi
  done
}


