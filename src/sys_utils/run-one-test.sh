#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/bash-guard.sh" || return
__bash_module_guard || return
#echo "SOURCING FILE: ${BASH_SOURCE[0]}"

### INCLUDES ###
source ./unittest-utilities.sh


### MAIN ###

# Kör en specificerad .tests-fil (ex: ./run-one-test.sh testcases/time.tests)
file="$1"

if [[ -z "$file" ]]; then
  echo "Användning: ./run-one-test.sh testcases/<filnamn>.tests"
  exit 1
fi

if [[ ! -f "$file" ]]; then
  echo "❌ Filen \"$file\" hittades inte."
  exit 1
fi


__run_test "$file"
