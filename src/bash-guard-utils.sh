#!/usr/bin/env bash

## OBS Just denna script får inte ha Bashguard
## Jag kommer att behöva ändra här och inte bli förhindrad av omdefinition

#  Förhindra direkt exekvering
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "❌ Denna fil är en modul och ska inte köras direkt."
  echo "Den ger dig tillgång att ladda ur och lista inladdade Mensura moduler/funktioner"
  echo "  list_loaded_modules"
  echo "  list_loaded_functions"
  echo "  unload_task_modules"
  echo "  load_task_modules"
  echo "  reset_task_modules"
  exit 1
fi

list_loaded_functions() {
  local RED='\033[0;31m'
  local GREEN='\033[0;32m'
  local BLUE='\033[1;34m'
  local RESET='\033[0m'

  echo -e "${BLUE}🔍 Söker efter Mensura-funktioner i inladdade moduler...${RESET}"

  local found_any=0
  local path

  for guardname in $(compgen -v | grep -E '^__GUARD_.*_LOADED$'); do
    path=$(__guard_var_to_filename $guardname)

    echo "$path"
    # Hämta alla funktioner definierade i filen
    grep -E '^\s*(function\s+)?[a-zA-Z0-9_-]+\s*\(\)' "$path" \
        | sed -E 's/^\s*(function\s+)?([a-zA-Z0-9_-]+).*/  └─ \2/' \
        | sort
  done
}

# Lista alla __TASK_*_LOADED-variabler
function list_loaded_modules() {
  for var in $(compgen -v | grep -E '^__GUARD_.*_LOADED$'); do
    echo "*> $var"
  done
}

function list_loaded_functions_deprecated() {
  echo "🔍 Söker efter Mensura-funktioner igenom de moduler som laddats in..."
  for func in $(compgen -v | grep -E '^__GUARD_.*_LOADED$'); do
    local value="${!var}"
    echo "val: $var"
    if [[ -n "$value" && -f "$value" ]]; then
      echo "📦 $value"
      grep -E '^\s*(function\s+)?[a-zA-Z0-9_-]+\s*\(\)' "$value" \
        | sed -E 's/^\s*(function\s+)?([a-zA-Z0-9_-]+).*/  └─ \2/' \
        | sort
    fi
  done
}


# Hitta alla __TASK_*_LOADED-variabler och unset:a dem
function unload_task_modules() {
  for var in $(compgen -v | grep -E '^__GUARD_.*_LOADED$'); do
    unset "$var"
    echo "🔓 Unset $var"
  done
}

# Funktion som hittar alla funktioner definierade i en given fil
# PARAM: Kompletta sökvägen till filen som innehåller de funktion du vill ladda ur
function unload_functions() {
  local script_file="$1"

  if [[ ! -f "$script_file" ]]; then
    echo "❌ Filen '$script_file' hittades inte."
    return 1
  fi

  echo "🔍 Söker efter funktioner definierade i $script_file..."

  local funcs=()
  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*(function[[:space:]]+)?([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(\)[[:space:]]*\{ ]]; then
      funcs+=("${BASH_REMATCH[2]}")
    fi
  done < "$script_file"

  if [[ ${#funcs[@]} -eq 0 ]]; then
    echo "⚠️ Inga funktioner hittades i $script_file."
    return 1
  fi

  echo "🚫 Tar bort funktioner:"
  for fn in "${funcs[@]}"; do
    if declare -f "$fn" > /dev/null; then
      echo "  🔸 $fn"
      unset -f "$fn"
    else
      echo "  ⚪ $fn (fanns ej aktivt definierad)"
    fi
  done
}


# Sourca alla task.*.sh på nytt
function load_task_modules() {
  for file in task-*.sh; do
    [[ -f "$file" ]] || continue
    echo "📦 Laddar $file"
    source "$file"
  done
}

# Kombinera båda
function reset_task_modules() {
  echo "🔁 Återställer alla task-moduler..."
  unload_task_modules
  load_task_modules
}

### -- PRIVATE FUNCTIONS -- ##
function __guard_var_to_filename() {
  local guardname
  local basedir

  guardname="$1"
  basedir="$(dirname "${BASH_SOURCE[0]}")"   # katalog där scriptet bor

  if [[ "$guardname" =~ ^__GUARD_(.*)_SH_LOADED$ ]]; then
    local core="${BASH_REMATCH[1]}"
    local filename
    filename=$(echo "$core" | tr '[:upper:]' '[:lower:]' | tr '_' '-')".sh"
    local filepath="$basedir/$filename"
    #echo "Basedir: $basedir   filename: $filename     filepath:$filepath"

    if [[ -f "$filepath" ]]; then
      echo "$filepath"
      return 0
    else
      echo "❌ Filen hittades inte: $filepath" >&2
      return 1
    fi
  else
    echo "❌ Ogiltigt format: $guardname" >&2
    return 2
  fi
}


# Det här behöer sourcas för att kunna köras ordentlig
# Jag trodde man kunde köra det som script

# param="$1"
# if [[ "$param" == "list-modules" ]] ; then
#   list_loaded_modules
# elif [[ "$param" == "list-functions" ]] ; then
#   list-loaded-functions
# elif [[ "$param" == "unload" ]] ; then
#   unload_task_modules
# elif [[ "$param" == "load" ]] ; then
#   load_task_modules
# elif [[ "$param" == "reset" ]] ; then
#   reset_task_modules
# else
#   echo "Okänt kommando: $param"
#   echo "Välj en av: "
#   echo "  list-modules"
#   echo "  list-functions"
#   echo "  unload"
#   echo "  load"
#   echo "  reset"
# fi
