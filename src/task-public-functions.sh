#!/bin/bash

#######
#
# SYFTE: Att ta emot funktions anrop från task-entrypoint.sh
# för att göra logiken som bygger upp Mensura funktioner till användare
#
#######

#  Förhindra direkt exekvering från kommandoprompten som ett script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "❌ Denna fil är en modul och ska inte köras direkt."
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
source "$__MENSURA_DIR/utilities.sh"      # Misc utilities
source "$__MENSURA_DIR/tui-config.sh"     # Textual User interface confug
source "$__MENSURA_DIR/task-config.sh"    # Mensura configs for default task variables
source "$__MENSURA_DIR/parse-datetime.sh" # Normaliserar och tolkar datum och tid
source "$__MENSURA_DIR/task-private.sh"   # Helper functions for the public task functions



### --- PUBLIC FUNCTIONS --- ###

# task-meeting "Titel"                     # => start = now, end = now + default
# task-meeting "Titel" 14:00               # => start = idag 14:00, end = +default
# task-meeting "Titel" 14:00 +45m          # => start = idag 14:00, end = +default
# task-meeting "Titel" fredag 14:00        # => start = kommande fredag 14:00
# task-meeting "Titel" fredag 14:00 15:00  # => start och slut exakt
# task-meeting "Titel" fredag 14:00 +45m   # => start och offset
task_meeting_parse_args() {
  local title="$1"; shift
  local part1="$1"; shift || true
  local part2="$1"; shift || true
  local part3="$1"; shift || true
  local tags=("$@")

  if  __is_date_based "$title" ; then
    echo "ERROR: Första parametern måste vara beskrivning"
    return 1
  fi




  echo "Title: $title"
  echo "P1: $part1"
  echo "P2: $part2"
  echo "P3: $part3"
  echo "tags: $tags"

  # Standardvärden
  local start_day="idag"
  local start_time=""
  local end_spec=""

  # Fall: Inga extra argument → nu + default
  if [[ -z "$part1" ]]; then
    start_time="now"
    end_spec="+$TASK_MEETING_LENGTH"

  # Fall: Enbart tid eller offset
  elif __is_time_or_offset "$part1" &>/dev/null; then
    start_time="$part1"
    end_spec="+$TASK_MEETING_LENGTH"

  # Fall: Namngiven dag + ev. tid
  elif __is_namegiven_day "$part1"; then
    start_day="$part1"
    if [[ -n "$part2" ]]; then
      start_time="$part2"
    else
      start_time="$(__task_get_config "TASK_START_OF_DAY")"
    fi

    if [[ -n "$part3" ]]; then
      end_spec="$part3"
    else
      end_spec="+$TASK_MEETING_LENGTH"
    fi

  # Fall: dag saknas men tid + offset
  else
    start_time="$part1"
    if [[ -n "$part2" ]]; then
      end_spec="$part2"
    else
      end_spec="+$TASK_MEETING_LENGTH"
    fi
  fi

  # Beräkna start och slut
  local start="$(__parse_datetime "$start_day" "$start_time")" || return 1

  local end=""
  if __is_time_or_offset "$end_spec" | grep -q "OFFSET"; then
    end="$(__add_offset_to_datetime "$start" "$end_spec")" || return 1
  else
    # Tolkas som tidpunkt samma dag
    read -r start_date _ < <(__split_datetime "$start")
    end="$(__parse_datetime "$start_date" "$end_spec")" || return 1
  fi

  # Exportera
  MEETING_TITLE="$title"
  MEETING_START="$start"
  MEETING_END="$end"
  MEETING_TAGS=("${tags[@]}")
}

##--
##@ task-meeting: Planera ett möte med naturligt datum/tid och kopplad till mötes-anteckning
#   task-meeting: Planera ett möte med start/slut och anteckningsfil, utan att starta mötet
function __entry_task_meeting() {
  local desc=""
  local day=""
  local start=""
  local end=""
  local tags=""

  # Kontrollera argument
  if [[ $# -lt 2 ]]; then
    echo "Användning: task-meeting \"Beskrivning\" [dag] starttid sluttid [taggar...]" >&2
    echo "Exempel: task-meeting \"Veckomöte\" fredag 10:00 +30m" >&2
    return 1
  fi

  desc="$1"; shift

  echo "Hello1"
  # Om nästa argument liknar en tid eller offset, sätt day till "idag"
  if __time_or_offset "$1" >/dev/null; then
    echo "Hello2"
    day="idag"
    start="$1"; shift
  else
    day="$1"; shift
    start="$1"; shift
  fi

  # Resterande argument
  end="$1"; shift
  tags="$*"

  echo "DESC: $desc"
  echo "DAY: $day"
  echo "START: $start"
  echo "END: $end"
  echo "TAGS: $tags"

  # # Konvertera tider
  # local start_iso end_iso
  # start_iso=$(__parse_datetime "$day" "$start") || return 1
  # end_iso=$(__parse_datetime "$day" "$end") || return 1

  # # Skapa TaskWarrior-task
  # local id
  # id=$(task add "$desc" project:meeting due:"$start_iso" wait:"$start_iso" +meeting $tags | grep -oP '(?<=Created task )[0-9]+') || {
  #   echo "❌ Kunde inte skapa task." >&2
  #   return 1
  # }

  # # Koppla anteckningsfil med metadata
  # local notes_dir="${TASK_NOTES_DIR:-$HOME/.mensura/notes}"
  # mkdir -p "$notes_dir"
  # local notes_file="$notes_dir/meeting-$id.txt"
  # {
  #   echo "🗓️  MÖTE: $desc"
  #   echo "📅 Datum: ${start_iso%%T*}"
  #   echo "⏰ Tid:   ${start_iso#*T} – ${end_iso#*T}"
  #   echo "🏷️  Taggar: $tags"
  # } > "$notes_file"

  # task annotate "$id" "Anteckningar: $notes_file"

  # echo "📌 Möte $id registrerat, redo att startas manuellt."
}


# ---
##@ task-us-pu: Används om du vill skapa en US eller PU task ---
function __entry_task-us-pu() {
  local desc="$1"
  if [[ -z "$desc" ]]; then
    echo "Ange en beskrivning, t.ex. 'PU-123: Refaktorera API'"
    echo "Kommer att definiera upp en TaskWarrior task med projekt och tagg baserat på beskrivningen"
    return 1
  fi

  shopt -s nocasematch
  local proj=""
  local jiraTag=""
  if [[ "$desc" =~ (PU-[0-9]+) ]]; then
    proj="utveckling"
    jiraTag="${BASH_REMATCH[1]}"
  elif [[ "$desc" =~ (US-[0-9]+) ]]; then
    proj="utredning"
    jiraTag="${BASH_REMATCH[1]}"
  else
    shopt -u nocasematch
    echo "Beskrivningen måste innehålla PU- eller US-nummer."
    return 1
  fi
  shopt -u nocasematch

  __task_create_uppgift "$desc" "$proj" "$jiraTag"
}

# ---
##@ task-teknik: Används om du vill skapa en Task för 'teknik' projekt, kopplat mot US/PU ärende
function __entry_task-teknik() {
  local desc="$1"
  if [[ -z "$desc" ]]; then
    echo "Ange en beskrivning, t.ex. 'PU-123: Refaktorera API'"
    return 1
  fi

  shopt -s nocasematch
  local jiraTag=""
  if [[ "$desc" =~ ((PU|US)-[0-9]+) ]]; then
    jiraTag="${BASH_REMATCH[1]}"
  else
    shopt -u nocasematch
    echo "Beskrivningen bör innehålla PU- eller US-nummer."
    return 1
  fi
  shopt -u nocasematch

  __task_create_uppgift "$desc" "teknik" "$jiraTag"
}


# ---
##@ task-brand: När systemen brinner och inget Jira ärende finns
function __entry_task-brand() {
  local desc="$*"
  local proj="brand"
  local tags="interrupted"
  local prio="Kritiskt"
  local due="now +30min"  # du kan justera detta
  local id=""

  if [ -z "$desc" ]; then
    echo "Apropos: Vid axelknack uppgifter. Du måste ange en beskrivning, t.ex. task-brand \"hjälpte Lisa med SSH nyckel\""
    return 1
  fi

  # Skapa uppgiften
  id=$(task add "$desc" project:$proj priority:$prio +$tags due:"$due" | grep -oP '(?<=Created task )[0-9]+')

  if [ -z "$id" ]; then
    echo "Kunde inte skapa uppgift!"
    return 1
  fi

  echo "Brandloggad som task $id: \"$desc\""

  # Starta den direkt
  task "$id" start
}

# ---
##@ task-brandlog: Logga tid i efterhand, när systemet slutat brinnar och inget Jira ärende finns
function __entry_task-brandlog() {
  local desc="$1"
  local start="$2"
  local dur="$3"
  local proj="brand"
  local tags="interrupted"
  local prio="Kritiskt"
  local today=""

  today=$(date +%F)  # idag i YYYY-MM-DD

  if [ -z "$desc" ] || [ -z "$start" ] || [ -z "$dur" ]; then
      echo "Vid loggning av tid i efterhand över axelknacknings-assistans"
      echo "Användning: task-brandlog \"beskrivning\" starttid duration"
      echo "Exempel   : task-brandlog \"Hjälpte Ullysses\" 14:05 20min"
      return 1
  fi

  local normDur
  normDur=$(__normalize_duration "$dur")

  # Beräkna start- och sluttid i format TimeWarrior gillar
  local starttime=$(date -d "$start" +"%H:%M:%S")
  local endtime=$(date -d "$start $normDur" +"%H:%M:%S")

  # Skapa task som färdig
  id=$(task add "$desc" project:$proj priority:$prio +$tags end:"$today $start" | grep -oP '(?<=Created task )[0-9]+')

  if [ -z "$id" ]; then
    echo "Kunde inte skapa uppgift!"
    return 1
  fi

  task "$id" done

  # Logga tiden retroaktivt i TimeWarrior
  timew track $starttime - $endtime tag:"$proj" +"$tags" +task"$id"
  if [[ "$?" = "0" ]] ; then
    echo "Brand loggad retroaktivt som task $id, med $dur från $start"
  else
    echo "Brand muisslyckades loggad retroaktivt som task $id, med $dur från $start"
    echo "Rollback på timew och task"
    task "$id" delete
  fi

}


## ---
##@ task-cancel: Avsluta ett givet ärende med ID, sätt tag till cancel
function __entry_task-canceled() {
  local id="$1"

  if [[ -z "$id" ]]; then
    echo "Ange ID för den Task du vill markera som avbruten"
    echo "Exempel: taskt-list ; task-canceled 17"
    return 1
  fi

  if ! task "$id" > /dev/null 2>&1; then
    echo "Task med ID $id finns inte"
    return 1
  fi

  echo "Stoppar och avbryter task $id..."
  task "$id" stop > /dev/null 2>&1
  task "$id" modify status:completed +canceled > /dev/null
  echo "Task $id markerad som avbruten"
}

##@ task-postpone: Flyttar fram en task (ange ID och nytt datum/tid)
function __entry_task-postpone() {
  local id="$1"
  local new_due="$2"

  if [[ -z "$id" || -z "$new_due" ]]; then
    echo "Användning: task-postpone <ID> <nytt datum>"
    echo "Exempel: task-postpone 42 \"friday 13:00\""
    return 1
  fi

  if ! task "$id" > /dev/null 2>&1; then
    echo "Task med ID $id finns inte"
    return 1
  fi

  if ! date -d "$new_due" > /dev/null 2>&1; then
    echo "Ogiltigt datum/tid: \"$new_due\""
    return 1
  fi

  # Hämta nuvarande 'due' (om det finns)
  local old_due
  old_due=$(task "$id" | awk -F': ' '/Due/ {print $2}')

  # Skapa tidsstämpel
  local now
  now=$(date "+%Y-%m-%d %H:%M")

  echo "Flyttar task $id till nytt datum: $new_due"
  task "$id" modify due:"$new_due" +postponed

  # Skapa annotation
  if [[ -n "$old_due" ]]; then
    task "$id" annotate "Flyttad från $old_due till $new_due den $now"
  else
    task "$id" annotate "Flyttad till $new_due den $now"
  fi

  echo "Task $id uppdaterad och annoterad"
}

## ---
##@ task-done: Markera uppgift som helt klar
function __entry_task-done() {
  echo "Markerar uppgift som avklarad"
  task +ACTIVE done
}

## ---
##@ task-fika: Markera uppgift som pausad
function __entry_task-fika() {
  echo "Markerar uppgiften som pausad"
  task +ACTIVE stop
}

## ---
##@ task-pause: Markera uppgift som pausad
function __entry_task-pause() {
  echo "Markerar uppgiften som pausad"
  task +ACTIVE stop
}

## ---
##@ task-resume: Återuppta senaste pausade ärendet
function __entry_task-resume() {
  echo "Sätter igång senaste uppgiften"
  task +READY +LATEST start
}

### -- Reporter ---

##@ task-export: Exportera TaskWarrior-uppgifter i Markdown-format
function __entry_task-export() {
  local filter="${1:-status:pending}"

  echo "### Task-export  filter: $filter"
  echo ""
  echo "| ID | Projekt | Prioritet | Beskrivning | Status |"
  echo "|----|---------|-----------|-------------|--------|"

  task $filter rc.report.markdown.columns:id,project,priority,description,status rc.report.markdown.labels:ID,Projekt,Prio,Beskrivning,Status rc.verbose:nothing rc.color=off | \
    awk -F'\t' 'NR>3 { printf "| %s | %s | %s | %s | %s |\n", $1, $2, $3, $4, $5 }'
}

##@ task-export-csv: Exportera TaskWarrior-uppgifter i CSV-format
function __entry_task-export-csv() {
  local filter="${1:-status:pending}"

  echo "ID,Projekt,Prioritet,Beskrivning,Status"
  task $filter rc.report.csv.columns:id,project,priority,description,status rc.report.csv.labels:ID,Projekt,Prio,Beskrivning,Status rc.verbose:nothing rc.color=off | \
    awk -F'\t' 'NR>3 { printf "\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"\n", $1, $2, $3, $4, $5 }'
}
