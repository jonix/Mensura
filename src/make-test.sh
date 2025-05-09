#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

# Fånga upp sökvägen till det här scriptet
if [[ -n "${BASH_SOURCE[0]}" ]]; then
  __THIS_SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
  __MENSURA_DIR="$(dirname "$__THIS_SCRIPT_PATH")"
fi
source "$__MENSURA_DIR/make-run-functions.sh"



### MAIN ####
make-exec "${__MENSURA_DIR}/run-one-test.sh" "$@"
