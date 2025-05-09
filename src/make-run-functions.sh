#!/usr/bin/env bash

set -uo pipefail
IFS=$'\n\t'

function help() {
    local progname="${1:-script}"
    echo ""
    echo "Enklare script för att välja vilken fil man vill köra $progname på"
    echo "Kan använda sig av fzf för att det ska vara lätt att välja vilken fil"
    echo ""
    echo "Parameter"
    echo "--help -h help h    > Skriv ut hjälptext"
    echo "existerande filer   > Kör $progname på de filerna, t ex file1.sh file2.sh  eller file*.sh "
    echo "fzf                 > Välj fil med fzf"
    echo "Inga parameter|alla > Väljer alla filer i testcases katalogen"
    echo ""
}

function inspect_command() {
  local cmd="${1:-}"

  # If the command contains a /, treat it as a path (absolute or relative)
  if [[ "$cmd" == */* ]]; then
    if [[ -x "$cmd" ]]; then
      echo "'$cmd' is an executable file"

      if head -n 1 "$cmd" | grep -q '^#!'; then
        echo "It is a script with shebang: $(head -n 1 "$cmd")"
        return 0
      else
        echo "It is likely a compiled binary (no shebang)"
        return 0
      fi
    else
      echo "'$cmd' is not an executable file or does not exist"
      return 1
    fi

  # Else: try to resolve it using PATH
  else
    local resolved
    resolved=$(command -v "$cmd" 2>/dev/null)

    if [[ -n "$resolved" && -x "$resolved" ]]; then
      echo "'$cmd' found in PATH → $resolved"
      if head -n 1 "$resolved" | grep -q '^#!'; then
        echo "It is a script with shebang: $(head -n 1 "$resolved")"
        return 0
      else
        echo "It is likely a compiled binary (no shebang)"
        return 0
      fi
    else
      echo "'$cmd' is not found in PATH or not executable"
      return 1
    fi
  fi
  return 1
}

function make-exec() {

# TODO: Parametrar hanteras simpelt för nu. Återkom vid behov för bättre separation. progparam kan bara ta en parameter
  local lintfiles=()
  local progname="${1:-}"
  local progparam="${2:-}"

  if [[ "$progname" == "--help" || "$progname" == "help" || "$progname" == "h" || "$progname" == "-h" ]] ; then
    help
    exit 0
  fi

  if inspect_command "$progname" > /dev/null ; then
      # Ta bort parameter 1 som är program-namnet
      shift

      if [[ -n "$progparam" ]] ; then
          # Ta bort parameter 2 som är program-parametrar
          shift
      fi
  else
      echo "ERROR: make-run-functions.sh make-exec: parameter 1 $progname är inte ett körbar program"
      return 1
  fi

  # Inget argument = kör på alla .sh-filer i nuvarande katalog
  if [[ $# -eq 0 ]]; then
    echo "Inga argument – kör på alla *.sh-filer i nuvarande katalog"
    mapfile -t lintfiles < <(find . -maxdepth 1 -type f -name '*.sh' | sort)

  # Argumentet är "fzf" eller "--fzf"
  elif [[ "$1" == "fzf" || "$1" == "--fzf" ]]; then
    local chosen
    chosen=$(find . -type f -name '*.sh' | sort | fzf --prompt="Välj Bash-fil: ")
    [[ -n "$chosen" ]] && lintfiles+=("$chosen")

  # Annars: behandla alla argument som filnamn
  else
    for f in "$@"; do
      if [[ -f "$f" ]]; then
        lintfiles+=("$f")
      else
        echo "Filen \"$f\" hittades inte – ignoreras"
      fi
    done
  fi

  if [[ ${#lintfiles[@]} -eq 0 ]]; then
    echo "Ingen giltig fil att lint:a"
    return 1
  fi

  echo "Kör med följande fil(er):"
  printf '  %s\n' "${lintfiles[@]}"
  echo ""

  for file in "${lintfiles[@]}"; do
    #echo "$progname $progparam $file"

    # Kör programmet med eventuell parameter, fil för file
    "$progname" "$progparam" "$file"

  done

  echo ""
  echo "OBS: Går att köra $progname med fil-filter"
  echo ""
}

