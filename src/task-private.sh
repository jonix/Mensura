#!/usr/bin/env bash

#  Förhindra direkt exekvering
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "❌ Denna fil är en modul och ska inte köras direkt."
  exit 1
fi


# Se till att denna file laddas in en och endast en gång
source "$(dirname "${BASH_SOURCE[0]}")/bash-guard.sh" || return
__bash_module_guard || return
#echo "SOURCING FILE: ${BASH_SOURCE[0]}"


### Includes ###
source "$(dirname "${BASH_SOURCE[0]}")/tui-logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/parse-datetime.sh"


# Splitta upp en sträng som ser ut som detta
# US-2351: Fixa foobar felet
# Till följande format
# |US|US-2351|US-2351: Fixa foobar felet
function __parse_arendetyp() {
  local desc="$1"
  if [[ "$desc" =~ ([Uu][Ss]|[Pp][Uu])-[0-9]+ ]]; then
    local raw="${BASH_REMATCH[0]}"
    local upper=$(echo "$raw" | tr '[:lower:]' '[:upper:]')
    local typ="${upper%%-*}"
    desc="${desc//$raw/$upper}"
    echo "$typ|$upper|$desc"
  else
    echo "NONE||$desc"
  fi
}

# Privat metod som används för både US, PU och Teknik ärenden
function __task_create_uppgift() {
  local desc="$1"
  local proj="$2"
  local jiraTag="$3"
  local jiraType=""
  local id=""
  local parseResult=""
  local normalizedDescr=""

  echo "Ange prioritet (Kritiskt, Betydande, Mindre, Ingen) [default: Betydande]:"
  read -r prio
  prio=${prio:-Betydande}

  case "$prio" in
    Kritiskt|Betydande|Mindre|Ingen)
      echo "Sätter prio till $prio"
      ;;
    *)
      echo "Ogiltig prioritet: $prio"
      __task_create_uppgift "$desc" "$proj" "$jiraTag"
      ;;
  esac

  #if [[ "$jiraTag" =~ ^(PU|US)-[0-9]+$ ]]; then
  #  jiraType="${BASH_REMATCH[1]}"
  #fi


  parseResult=$(__parse_arendetyp "$desc")
  IFS='|' read -r jiraType jiraTag normalizedDescr <<< "$parseResult"

  #echo "desc    : $desc"
  #echo "desc2   : $parseResult"
  #echo "proj    : $proj"
  #echo "jiraTag : $jiraTag"
  #echo "jiraType: $jiraType"
  #return 1


  echo "Skapar task i projekt '$proj' med tagg '$jiraType' och prioritet '$prio'"


  id=$(task add "$normalizedDescr" project:$proj priority:"$prio" +$jiraType | grep -oP '(?<=Created task )[0-9]+') || {
    echo "Kunde inte skapa task"
    return 1
  }

  echo "Skapad som task $id"

  #echo "Startar uppgiften..."
  #task "$id" start
}


