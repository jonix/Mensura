#!/usr/bin/env bash

#!/usr/bin/env bash


#  Förhindra direkt exekvering
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "ERROR: Denna fil är en modul och ska inte köras direkt."
  exit 1
fi


# Se till att denna file laddas in en och endast en gång
source "$(dirname "${BASH_SOURCE[0]}")/bash-guard.sh" || return
__bash_module_guard || return


function abcd() {
    echo "hello"
}

function bcdef() {
    echo "bye"
}
