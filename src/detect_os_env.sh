#!/usr/bin/env bash


#  Förhindra direkt exekvering
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "ERROR: Denna fil är en modul och ska inte köras direkt."
  exit 1
fi


# Se till att denna file laddas in en och endast en gång
source "$(dirname "${BASH_SOURCE[0]}")/bash-guard.sh" || return
__bash_module_guard || return


function frotz2() {
    echo "hello"
}

function detect_os_env() {
    # Först, ta reda på uname -s
    local kernel="$(uname -s)"
    # WSL identifieras via /proc/version
    if [[ "$kernel" == "Linux" ]]; then
        if grep -qi microsoft /proc/version 2>/dev/null; then
            echo "wsl"
            return
        fi
        echo "linux"
    elif [[ "$kernel" == "Darwin" ]]; then
        echo "mac"
    else
        echo "unknown"
    fi
}
