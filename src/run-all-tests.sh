#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/bash-guard.sh" || return
__bash_module_guard || return
#echo "SOURCING FILE: ${BASH_SOURCE[0]}"

### INCLUDES ###
source ./unittest-utilities.sh


### MAIN ###
for file in testcases/*.test; do
  __run_test "$file"
done
