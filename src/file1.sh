#!/usr/bin/env bash

echo "File1 Start"

# Se till att denna file laddas in en och endast en gång
source "$(dirname "${BASH_SOURCE[0]}")/bash-guard.sh" || return
__bash_module_guard || return
echo "SOURCING FILE: ${BASH_SOURCE[0]}"

echo "File1 End"
