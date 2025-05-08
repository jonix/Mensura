#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Plats för cache-filen
CACHE="${HOME}/.cache/bash-known-cmds.txt"
mkdir -p "$(dirname "$CACHE")"

# Använd en assoc-array för att undvika dubletter
declare -A seen

# 1) shell-builtins
for cmd in $(compgen -b); do
  seen["$cmd"]=1
done

# 2) shell-keywords
for kw in $(compgen -k); do
  seen["$kw"]=1
done

# 3) aliaser
while read -r line; do
  # alias-format: name='definition'
  name="${line%%=*}"
  seen["$name"]=1
done < <(alias)

# 4) funktioner i miljön
#for fn in $(compgen -A function); do
#  seen["$fn"]=1
#done

# 5) externa program i $PATH
IFS=':' read -ra DIRS <<< "$PATH"
for d in "${DIRS[@]}"; do
  [[ -d $d ]] || continue
  for f in "$d"/*; do
    [[ -x $f && ! -d $f ]] && seen["${f##*/}"]=1
  done
done

# Skriv ut och sortera unikt
printf '%s\n' "${!seen[@]}" | sort > "$CACHE"
echo "Wrote ${#seen[@]} commands to $CACHE"
