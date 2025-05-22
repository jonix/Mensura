#!/usr/bin/env bash

# bash-guard.sh
# Source guard som automatiskt skyddar modul-filer från att laddas flera gånger
#
# --- EXEMPEL ---
# Lägg in följande två rader i varje fil som bara ska laddas in en gång, oavsett hur många script som sourcar/laddar filen
# source "$(dirname "${BASH_SOURCE[0]}")/bash-guard.sh" || return
# __bash_module_guard || return
#
#

#  Förhindra direkt exekvering från kommandoprompten som ett script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "❌ Denna fil är en modul och ska inte köras direkt."
  exit 1
fi

function __bash_module_guard() {
  local source_file="${BASH_SOURCE[1]}"
  local base_name guard_name

  base_name=$(basename "$source_file")
  guard_name="__GUARD_$(echo "$base_name" | tr 'a-z' 'A-Z' | sed 's/[^A-Z0-9]/_/g')_LOADED"

  #echo "BG: base_name: $base_name"
  #echo "BG: guard_name: $guard_name"

  if [[ -n "${!guard_name:-}" ]]; then
    return 1  # Redan laddad
  fi

  ## Hmm... readonly gjorde så att jag inte ens kunde göra en unset och rensa bort variablerna
  ##readonly "$guard_name"=1
  ## Rekommenderas till detta, kan unsettas och ärvs inte till child-shells
  eval "$guard_name=1"

  return 0  # Nytt, fortsätt ladda
}
