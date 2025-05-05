#!/usr/bin/env bash

echo "this: ${BASH_SOURCE[0]}"

# Fånga upp sökvägen till det här scriptet
if [[ -n "${BASH_SOURCE[0]}" ]]; then
  __THIS_SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
  __MENSURA_DIR="$(dirname "$__THIS_SCRIPT_PATH")"
fi
source "$__MENSURA_DIR/file1.sh"
source "$__MENSURA_DIR/file2.sh"
