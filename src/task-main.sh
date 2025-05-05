#!/usr/bin/env bash

# Se till att denna file laddas in en och endast en gång
source "$(dirname "${BASH_SOURCE[0]}")/bash-guard.sh" || return
__bash_module_guard || return
#echo "SOURCING FILE: ${BASH_SOURCE[0]}"




# Fånga upp sökvägen till det här scriptet
#if [[ -n "${BASH_SOURCE[0]}" ]]; then
#  __TASK_SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
#  __TASK_CORE_DIR="$(dirname "$__TASK_SCRIPT_PATH")"
#fi



# Sourca config relativt till scriptets plats:
#source "$__TASK_SCRIPT_DIR/task-config.sh"
#source "$__TASK_SCRIPT_DIR/task-public.sh"
#source "$__TASK_SCRIPT_DIR/task-private.sh"
