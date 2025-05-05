#!/bin/bash

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


##--
##@ task-meeting:
function task-meeting() {
  local desc=""
  local day=""
  local start=""
  local end=""
  local tags=""

  # Kontrollera argument
  if [[ $# -lt 2 ]]; then
    echo "❌ Användning: task-meeting \"Beskrivning\" [dag] starttid sluttid [taggar...]" >&2
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


##--
##@ task-meeting: Planera ett möte med naturligt datum/tid och kopplad till mötes-anteckning
task-meeting-deprecated() {
  local desc="$1"
  local day="$2"
  local start_in="$3"
  local end_in="$4"
  local extra_tags="$5"

  if [[ -z "$day" ]] ; then
    day=$(__parse_today_str "today")
  fi
  echo "DAY: $day"

  if [[ -z "$desc" ]] || [[ -z "$start_in" ]]; then
    echo "Användning: task-meeting \"Beskrivning\" (dag) <starttid> [sluttid/offset] [taggar]"
    echo "Exempel:   task-meeting \"Veckomöte\" now"
    echo "Exempel:   task-meeting \"Veckomöte\" 14:00 15:00"
    echo "Exempel:   task-meeting \"Veckomöte\" today 14:00 15:00"
    echo "Exempel:   task-meeting \"Veckomöte\" fredag 14:00 15:00"
    echo "Exempel:   task-meeting \"Veckomöte\" fredag 14:00  (30min antas)"
    return 1
  fi

  local start_iso end_iso
  start_iso=$(__parse_datetime "$day" "$start_in") || return 1


  echo "HEJ1"
  if [[ -n "$end_in" ]]; then
    # Sluttid eller offset angiven
    if [[ "$(__time_or_offset "$end_in")" == "OFFSET" ]]; then
      echo "HEJ2"
      end_iso=$(date -d "$start_iso $(__normalize_offset "$end_in")" +"%Y-%m-%dT%H:%M")
    else
      echo "HEJ3"
      end_iso=$(__parse_datetime "$day" "$end_in") || return 1
    fi
  else
    echo "HEJ4"
    # Använd default mötestid
    local offset="${TASK_MEETING_LENGTH:-30 minutes}"
    end_iso=$(date -d "$start_iso $offset" +"%Y-%m-%dT%H:%M")
  fi
  echo "HEJ5"

  local proj="${TASK_DEFAULT_PROJECT:-möten}"
  local prio="${TASK_DEFAULT_PRIO:-Mindre}"
  local tags="+meeting"
  [[ -n "$extra_tags" ]] && tags+=" +$extra_tags"

  local id note_file
  id=$(task add "$desc" project:$proj priority:$prio due:$start_iso $tags | grep -oP '(?<=Created task )[0-9]+') || {
    echo "❌ Kunde inte skapa mötes-task"
    return 1
  }

  note_file="$HOME/.mensura/notes/meeting-${id}.md"
  mkdir -p "$(dirname "$note_file")"

  {
    echo "# 🗓️ Mötesanteckningar för: $desc"
    echo ""
    echo "- Planerad start: $start_iso"
    echo "- Planerat slut:  $end_iso"
    echo ""
    echo "---"
    echo ""
  } > "$note_file"

  task "$id" annotate "Anteckningsfil: $note_file"
  task "$id" annotate "Slut: $end_iso"

  echo "✅ Mötet \"$desc\" registrerat som task $id"
  echo "📝 Anteckningar sparas i: $note_file"
}


## ---
##
##@ task-meeting: Planera ett möte med start/slut och anteckningsfil, utan att starta mötet
task-meeting---deprecacated() {
  local desc="$1"
  local day="$2"
  local start="$3"
  local end="$4"
  shift 4
  local taglist=("$@")

  if [[ -z "$desc" || -z "$day" || -z "$start" || -z "$end" ]]; then
    echo "Användning: task-meeting <beskrivning> <dag/datum> <starttid> <sluttid|duration> [taggar...]"
    echo "Exempel: task-meeting \"Möte med teamet\" fredag 13:30 14:15 tagg1 tagg2"
    echo "Eller:    task-meeting \"Möte med Lisa\" måndag 09:00 45m planering"
    return 1
  fi

  # 🧠 Tolkning av starttid
  local start_iso
  start_iso=$(__parse_datetime "$day" "$start") || return 1

  # 🕒 Tolkning av sluttid (kan vara offset eller klockslag)
  local end_iso
  if [[ "$end" =~ ^[0-9]+([hm]|min|m|minuter|timme|h)?$ ]]; then
    # Det är en duration → tolka som offset
    local offset
    offset=$(__normalize_offset "$end") || return 1
    end_iso=$(LC_TIME=en_US.UTF-8 date -d "$start_iso $offset" "+%Y-%m-%dT%H:%M") || return 1
  else
    # Det är en specifik tid → kombinera med datum
    local normalized_time
    normalized_time=$(__normalize_time "$end") || return 1
    end_iso=$(__parse_datetime "$day" "$normalized_time") || return 1
  fi

  # Metadata
  local proj="$(__task_get_config TASK_DEFAULT_PROJECT)"
  local prio="$(__task_get_config TASK_DEFAULT_PRIO)"

  # Skapa uppgiften
  local id
  id=$(task add "$desc" project:$proj priority:$prio due:"$start_iso" +meeting "${taglist[@]/#/ +}" \
    | grep -oP '(?<=Created task )[0-9]+') || {
    echo "❌ Kunde inte skapa task"
    return 1
  }

  # Annotera mötesmetadata
  task "$id" annotate "Planerat start: $start_iso"
  task "$id" annotate "Planerat slut: $end_iso"

  # Skapa anteckningsfil
  local notes_dir="${TASK_NOTES_DIR:-$HOME/.task-notes}"
  mkdir -p "$notes_dir"
  local note_file="$notes_dir/meeting-$id.md"

  cat > "$note_file" <<EOF
# Möte: $desc

**Starttid:** $start_iso
**Sluttid:**  $end_iso
**Task-ID:**  $id
**Taggar:**   ${taglist[*]}

---

Här kan du skriva anteckningar under mötet...
EOF

  echo "✅ Mötet \"$desc\" är planerat (task $id)"
  echo "📝 Anteckningsfil skapad: $note_file"
}



# ---
##@ task-us-pu: Används om du vill skapa en US eller PU task ---
task-us-pu() {
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
task-teknik() {
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
task-brand() {
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
task-brandlog() {
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
task-canceled() {
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
task-postpone() {
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
task-done() {
  echo "Markerar uppgift som avklarad"
  task +ACTIVE done
}

## ---
##@ task-fika: Markera uppgift som pausad
task-fika() {
  echo "Markerar uppgiften som pausad"
  task +ACTIVE stop
}

## ---
##@ task-pause: Markera uppgift som pausad
task-pause() {
  echo "Markerar uppgiften som pausad"
  task +ACTIVE stop
}

## ---
##@ task-resume: Återuppta senaste pausade ärendet
task-resume() {
  echo "Sätter igång senaste uppgiften"
  task +READY +LATEST start
}

### -- Reporter ---

##@ task-export: Exportera TaskWarrior-uppgifter i Markdown-format
task-export() {
  local filter="${1:-status:pending}"

  echo "### Task-export  filter: $filter"
  echo ""
  echo "| ID | Projekt | Prioritet | Beskrivning | Status |"
  echo "|----|---------|-----------|-------------|--------|"

  task $filter rc.report.markdown.columns:id,project,priority,description,status rc.report.markdown.labels:ID,Projekt,Prio,Beskrivning,Status rc.verbose:nothing rc.color=off | \
    awk -F'\t' 'NR>3 { printf "| %s | %s | %s | %s | %s |\n", $1, $2, $3, $4, $5 }'
}

##@ task-export-csv: Exportera TaskWarrior-uppgifter i CSV-format
task-export-csv() {
  local filter="${1:-status:pending}"

  echo "ID,Projekt,Prioritet,Beskrivning,Status"
  task $filter rc.report.csv.columns:id,project,priority,description,status rc.report.csv.labels:ID,Projekt,Prio,Beskrivning,Status rc.verbose:nothing rc.color=off | \
    awk -F'\t' 'NR>3 { printf "\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"\n", $1, $2, $3, $4, $5 }'
}
