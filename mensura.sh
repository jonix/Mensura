#!/usr/bin/env bash

#######
#
# SYFTE: Publik ingång till Mensura från användarens perspektiv
# Genom att ladda in den här filen (source ~/mensura-dir/task-entrypoint.sh i filen ~/.bashrc)
# Så kan man från terminalen använda sig av följande funktionalitet
#  - task-meeting:
#  - task-us-pu:    Används om du vill skapa en US eller PU task ---
#  - task-teknik:   Används om du vill skapa en Task för 'teknik' projekt, kopplat mot US/PU ärende
#  - task-brand:    När systemen brinner och inget Jira ärende finns
#  - task-brandlog: Logga tid i efterhand, när systemet slutat brinnar och inget Jira ärende finns
#  - task-cancel:   Avsluta ett givet ärende med ID, sätt tag till cancel
#######

#  Förhindra direkt exekvering från kommandoprompten som ett script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Denna fil ar en modul och ska inte köras direkt."
  exit 1
fi

# Se till att denna file laddas in en och endast en gång
#source "$(dirname "${BASH_SOURCE[0]}")/bash-guard.sh" || return
#__bash_module_guard || return
#echo "SOURCING FILE: ${BASH_SOURCE[0]}"

### --- INCLUDES --- ###
# Fånga upp sökvägen till det här scriptet
if [[ -n "${BASH_SOURCE[0]}" ]]; then
  __THIS_SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
  __MENSURA_DIR="$(dirname "$__THIS_SCRIPT_PATH")"
fi

source "$__MENSURA_DIR/task-public-functions.sh"  # Translates entry point to implementation of  public Mensura functions


### --- PUBLIC FUNCTIONS --- ###


##--
##@ task-meeting: Planera ett möte med naturligt datum/tid och kopplad till mötes-anteckning
#   task-meeting: Planera ett möte med start/slut och anteckningsfil, utan att starta mötet
function task_meeting() {
  __xxx_entry_task-meeting "$@"
  return $?
}


# ---
##@ task-us-pu: Används om du vill skapa en US eller PU task ---
function task-us-pu() {
  __entry-task-us-pu "$@"
  return $?
}

# ---
##@ task-teknik: Används om du vill skapa en Task för 'teknik' projekt, kopplat mot US/PU ärende
function task-teknik() {
  __entry-task-teknik "@"
  return $?
}


# ---
##@ task-brand: När systemen brinner och inget Jira ärende finns
function task-brand() {
  __entry-task-brand "$@"
  return $?
}

# ---
##@ task-brandlog: Logga tid i efterhand, när systemet slutat brinnar och inget Jira ärende finns
function task-brandlog() {
  __entry_task-brandlog "$@"
  return $?
}


## ---
##@ task-cancel: Avsluta ett givet ärende med ID, sätt tag till cancel
function task-canceled() {
  __entry-task-canceled "$@"
  return $?
}

##@ task-postpone: Flyttar fram en task (ange ID och nytt datum/tid)
function task-postpone() {
  __entry-task-postpone "$@"
  return $?
}

## ---
##@ task-done: Markera uppgift som helt klar
function task-done() {
  __entry-task-done "$@"
  return $?
}

## ---
##@ task-fika: Markera uppgift som pausad
function task-fika() {
  __entry-task-fika "$@"
  return $?
}

## ---
##@ task-pause: Markera uppgift som pausad
function task-pause() {
  __entry-task-pause "$@"
}

## ---
##@ task-resume: Återuppta senaste pausade ärendet
function task-resume() {
  __entry-task-resume "$@"
  return $?
}

### -- Reporter ---

##@ task-export: Exportera TaskWarrior-uppgifter i Markdown-format
function task-export() {
  __entry-task-export "$@"
  return $?
}

##@ task-export-csv: Exportera TaskWarrior-uppgifter i CSV-format
function task-export-csv() {
  __entry-task-export-csv "$@"
  return $?
}
