#!/usr/bin/env bash

# Modulfil, förhindra direkt exekvering, som ett script från kommandoraden
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "❌ Denna fil är en modul och ska inte köras direkt."
  exit 1
fi

# Garantera att bara ladda in modulen en gång
source "$(dirname "${BASH_SOURCE[0]}")/bash-guard.sh" || return
__bash_module_guard || return
#echo "SOURCING FILE: ${BASH_SOURCE[0]}"


### Includes ###
source "$(dirname "${BASH_SOURCE[0]}")/tui-config.sh"


#### Funktioner ###
####
__log_info() {
  local msg="$1"
  local caller="${FUNCNAME[1]}"
  local full="ℹ︎ [$caller] $msg"

  if [ -t 1 ]; then
    echo -e "${BLUE}$full${RESET}"
  else
    echo "$full"
  fi
}

__log_success() {
  local msg="$1"
  local caller="${FUNCNAME[1]}"
  local full="✔︎ [$caller] $msg"

  if [ -t 1 ]; then
    echo -e "${GREEN}$full${RESET}"
  else
    echo "$full"
  fi
}

__log_warn() {
  local msg="$1"
  local caller="${FUNCNAME[1]}"
  local full="⚠︎ [$caller] $msg"

  if [ -t 1 ]; then
    echo -e "${YELLOW}$full${RESET}" >&2
  else
    echo "$full" >&2
  fi
}

__log_error() {
  local msg="$1"
  local caller="${FUNCNAME[1]}"
  local full="❌ [$caller] $msg"

  if [ -t 1 ]; then
    echo -e "${RED}$full${RESET}"   | tee /dev/stderr
  else
    echo "$full" | tee /dev/stderr
  fi
}

__log_debug() {
  local msg="$1"
  local caller="${FUNCNAME[1]}"
  local full="🐞 [$caller] $msg"

  DEBUG="true"
  if [[ "$DEBUG" == "true" ]]; then
    if [ -t 1 ]; then
      echo -e "${GRAY}$full${RESET}" >&2
    else
      echo "$full" >&2
    fi
  fi
}
