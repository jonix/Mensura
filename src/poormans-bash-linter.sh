#!/usr/bin/env bash
# bash-lint.sh – Warn for undefined Bash-function calls
#set -euo pipefail
IFS=$'\n\t'

# 1) Hitta alla .sh-filer att granska
if [ $# -gt 0 ]; then
  files=()
  for path in "$@"; do
    if [ -d "$path" ]; then
      while IFS= read -r -d $'\0' f; do files+=("$f"); done \
        < <(find "$path" -type f -name '*.sh' -print0)
    elif [ -f "$path" ]; then
      files+=("$path")
    fi
  done
else
  files=()
  while IFS= read -r -d $'\0' f; do files+=("$f"); done \
    < <(find . -type f -name '*.sh' -print0)
fi

# 2) Läs in alla funktionsdefinitioner
declare -A defined_funcs
for file in "${files[@]}"; do
  while IFS= read -r line; do
    if [[ $line =~ ^[[:space:]]*(function[[:space:]]+)?([A-Za-z_][-A-Za-z0-9_]*)[[:space:]]*(\(\))?[[:space:]]*\{$ ]]; then
      fn="${BASH_REMATCH[2]}"
      defined_funcs["$fn"]=1
    fi
  done < "$file"
done

echo "Hittade ${#defined_funcs[@]} funktioner."

# 3) Ladda cache med kända kommandon
CACHE="${HOME}/.cache/bash-known-cmds.txt"
if [[ ! -f $CACHE ]]; then
  echo "VARNING: Cache-fil saknas!"
  exit 1
fi

declare -A known_cmds
while IFS= read -r cmd; do
  cmd="${cmd//$'\r'/}"
  [[ -n $cmd ]] && known_cmds["$cmd"]=1
done < "$CACHE"

echo "Hittade ${#known_cmds[@]} systemfunktioner."

# 4) Skanna efter potentiella anrop och jämför
error_count=0
declare -a errors

for file in "${files[@]}"; do
  while IFS=: read -r lineno token; do
    if [[ -z "${defined_funcs[$token]:-}" && -z "${known_cmds[$token]:-}" ]]; then
      errors+=("$token|$file|$lineno")
      ((error_count++))
    fi
  done < <(
    sed -E '
      s/#.*$//;                          # ta bort kommentarer
      s/\[\[[^]]*\]\]//g;                # ta bort [[ ... ]]-block
      s/\[[^]]*\]//g;                    # ta bort [ ... ]-block
      s/"([^"\\]|\\.)*"/"/g;             # ersätt "…" med bara ett "
      s/'\''([^'\''\\]|\\.)*'\''/'\''/g  # ersätt '\''…'\'' med bara '\''
      /^[[:space:]]*(echo|IFS|if|elif|else|for|while|done|declare)\b/ d
    ' "$file" \
    | grep -Eno '[A-Za-z_][-A-Za-z0-9_-]*(\(|[[:space:]]+(\$|"))' \
    | sed -E 's/(\(|[[:space:]]+(\$|"))$//'
  )
done

# 5) Rapportera
if (( error_count == 0 )); then
  echo "Inga odefinierade anrop hittades."
  exit 0
else
  echo "Hittade $error_count odefinierade funktionsanrop:"
  printf "  Function %-20s File %-30s \n" "Name" "Path"
  printf "  %-70s\n" "-----------------------------------------------------------------------"
  for e in "${errors[@]}"; do
    IFS='|' read -r name path line <<<"$e"
    printf "  %-20s %-30s %s\n" "$name" "$path"
  done
  exit 1
fi
