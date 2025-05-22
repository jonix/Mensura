#!/usr/bin/env bash


#######
#
# SYFTE:
# Att implementera mötes-hantering i Mensura med TaskWarrior och TimeWarrior som backend
#
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
