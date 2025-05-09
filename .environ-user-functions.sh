#!/usr/bin/env bash

#########
#
# En script fil där man kan sätta upp olika
# Miljö/Bash variabler som är specifika för Mensura
#
# Om du vill ha enklare utvecklings-vardag, gör en
# source environ.rc
#
# Om du vill göra det mycket lättare för dig, installera direnv
# och i terminalen skapa filen  $MensuraDir/.envrc med koden
#   source_env "environ.rc"
# och i terminalen skriv
# direnv allow
#
#########

test-environ() {
    echo "Hello World"
}

# make-test() {
#   local testfile
#   testfile=$(find testcases -type f -name '*.test' 2>/dev/null | sort | fzf --prompt="Välj testfil: ")

#   if [ -n "$testfile" ]; then
#     echo "▶️  make test F=$testfile"
#     make test F="$testfile"
#   else
#     echo "❌ Inget val gjort."
#   fi
# }

# make-lint() {
#   local lintfile
#   lintfile=$(find . -type f -name '*.sh' | sort | fzf --prompt="Lint en Bash-fil: ")

#   if [ -n "$lintfile" ]; then
#     echo "🔍 make lint F=$lintfile"
#     make lint F="$lintfile"
#   else
#     echo "❌ Inget val gjort."
#   fi
# }
