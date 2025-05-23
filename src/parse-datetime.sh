#!/usr/bin/env bash

set -uo pipefail
#set -u

### -- FUNKTIONS-LISTA --- ###
#
#  __parse_datetime      - Tolkar en fritext sträng till YYYY-MM-DDThh:mm
#  __parse_namegiven_day - Tolkar namngivna dagar, som imorgon, idag, mån, måndag, mon till YYYY-MM-DDThh:mm
#  __parse_now_time      - Tolkar now, nu till YYY-MM-DDThh:mm
#
#  __normalize_datetime - Normalisera datum-tid sträng, hanterar en mängd olika format
#  __normalize_date     - Normaliserar en sträng till ett datum,
#  __normalize_time     - Normaliserar en sträng till ett klockslag
#  __normalize_duration - Normaliserar en långvarighet
#  __normalize_offset   - Normaliserar en offset till ett klockslag
#  __normalize_day      - En given dag, antingen svenska eller engelska namn
#
# __is
# __is_valid_date
# __is_valid_datetime
# __is_time_or_offset
# __is_namegiven_day    - Returnerar 0 eller 1 om parametern är känd namngiven dag
# __is_only_date_string - Returnerar 0 om en sträng enbart innerhållet ett datum (validerar) eller 1 om det inte stämmer
# __is_date_string      - Returnerar 0 om en sträng börjar som ett datum (validerar) eller 1 om det inte stämmer (kan innehålla timestamps och offset)
# __is_datetime
#
# __trim                - Tar bort whitespace i början och slutet av strängen
# __combine_datetime  - Kombinerar 2 parametrar till str1Tstr2 (tänkt för att kombinera 'YYYY-MM-DD' 'HH:MM' till YYYY-MM-DDTHH:MM )


#  Förhindra direkt exekvering
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "ERROR: Denna fil är en modul och ska inte köras direkt."
  exit 1
fi


# Se till att denna file laddas in en och endast en gång
source "$(dirname "${BASH_SOURCE[0]}")/bash-guard-filecache.sh" || return
__bash_filecache_guard || return



### INCLUDES ###
source "$(dirname "${BASH_SOURCE[0]}")/utilities.sh"
source "$(dirname "${BASH_SOURCE[0]}")/task-config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/tui-logging.sh"

# TOO compliated just now
# function __get_datetime_type() {
#   local input="$*"
#   input="$(__trim "$input")"
#
#   if [[ -z "$input" ]]; then
#     echo "UNKNOWN"
#     return 1
#   fi
#
#   if [[ "$input" =~ ^(now|nu)$ ]]; then
#     echo "NOW"
#     return 0
#   fi
#
#   if __is_namegiven_day "$input"; then
#     echo "NAMED_DAY"
#     return 0
#   fi
#
#   if __is_valid_date "$input" &>/dev/null; then
#     echo "DATE"
#     return 0
#   fi
#
#   if __is_time_or_offset "$input" &>/dev/null; then
#     local kind="$(__is_time_or_offset "$input")"
#     echo "$kind"
#     return 0
#   fi
#
#   if __is_iso_datetime "$input" ; then
#     echo "ISO_DATETIME"
#     return 0
#   fi
#
#   if __is_datetime "$input" ; then
#     echo "DATETIME"
#     return 0
#   fi
#
#   echo "DESCRIPTION"
#   return 1
# }



#@ Tolkar en fritext sträng och returnerar YYYY-MM-DDThh:mm
# Går att att skicka datum och tid som en sträng eller som två parametrar
# Param 1: Datum
#    idag imorgon nu now
#    Namngivna dagar
#    yyyy-mm-dd
#    yyyymmdd
#    mm-dd
#    mmdd
#
# Param 2: Tid eller offset
#    01:30
#    0130
#    01.30
#    +20m
#    +1h
#    +1h30m
#
function __parse_datetime() {
  local input="$*"
  local date_part=""
  local time_part=""

  # local debugMode=0

  # Dela upp argument i två delar
  if [[ $# -eq 1 ]]; then
    local split
    split=$(__combine_datetime "$1")
    date_part="${split%%T*}"
    time_part="${split#*T}"
  elif [[ $# -eq 2 ]]; then
    date_part="$1"
    time_part="$2"
  else
    echo "ERROR: Fel antal argument till __parse_datetime"
    return 1
  fi

  local start_of_day=""
  start_of_day="$(__task_get_config "TASK_START_OF_DAY" 2>/dev/null || echo "08:00")"

  # Hanterar ISO formaterad datumTtid
  if __is_iso_datetime "$*" ; then
    local input
    input="$*"
    norm_date="$(__normalize_date "$date_part")" || return 1
    norm_time="$(__normalize_time "$time_part")" || return 1

    echo  "${norm_date}T${norm_time}"
    return 0
  fi

  #echo "DEBUG: date-input: $date_part"
  #echo "DEBUG: time-input: $time_part"

  # Vi ser till att inte matcha datum på formatet MMDD som datum här
  # Formatet med 4 tecken, är mer troligt ett klockslag än ett datum
  if [[ ${#date_part} -gt 4 ]] ; then
    kind="$(__is_only_date_string "$date_part $time_part")"
    local kind_rc=$?
    if [[ "$kind_rc" == "0" ]] ; then
      local norm_date="$(__normalize_date "$date_part")" || return 1
      echo "${norm_date}T${start_of_day}"
      return 0
    fi
  fi

  # Hantera fall där enda parametern är ett klockslag eller en offset
  #echo "DEBUG: __is_time_or_offset "
  local kind
  kind="$(__is_time_or_offset "$date_part")"
  local kind_rc=$?
  if [[ "$kind_rc" == "0" ]] ; then
    #echo "DEBUG: Matcha mot __is_time_or_offset"
    if [[ "$kind" == "TIME" ]]; then
      local date_today=$(date +%Y-%m-%d)
      local t="$(__normalize_time "$date_part")"
      echo "${date_today}T${t:0:5}"
      return 0
    elif [[ "$kind" == "OFFSET" ]]; then
      local now_time="$(__parse_now_time $date_part)"
      echo "$now_time"
      return 0
    fi
  fi



  # -- Hantera klockslag
  # Endast tid: HH:MM, HH.MM
  #if [[ "$input" =~ ^([0-9]{1,2}(:| )[0-9]{2}|[0-9]{1,2}\.[0-9]{2})$ ]]; then
  #  echo "TIME"
  #  return 0
  #fi

  # Hantera  4-siffrig tid: HHMM
  #if [[ "$input" =~ ^[0-9]{4}$ ]]; then
  #  echo "TIME"
  #  return 0
  #fi

  # Hantera now/nu (med offset)
  #echo "DEBUG: Hantera now/nu (med offset)"
  if [[ "${date_part,,}" =~ ^(nu|now)$ ]]; then
    __parse_now_time "$date_part $time_part"
    return $?
  fi

  # Hantera namngivna dagar eller today/tomorrow
  #echo "DEBUG: __is_namegiven_day"
  if __is_namegiven_day "$date_part"; then
    local base=""
    base="$(__parse_namegiven_day "$date_part")" || return 1
    if [[ -z "$time_part" ]]; then
      echo "$base"
      return 0
    fi
    if __is_time_or_offset "$time_part" | grep -q "OFFSET"; then
      __add_offset_to_datetime "$base" "$time_part"
    else
      local norm="$(__normalize_time "$time_part")" || return 1
      echo "${base%%T*}T${norm:0:5}"
    fi
    return 0
  fi

  # Annars: tolka datumet explicit
  #echo "DEBUG: tolka datum explicit"
  if ! __is_valid_date "$date_part"; then
    echo "ERROR: Ogiltigt datum: $date_part"
    return 1
  fi
  local norm_date="$(__normalize_date "$date_part")" || return 1

  # Inget klockslag angivet ? start-of-day
  #echo "DEBUG: Inget klockslag angivet, => start of day"
  if [[ -z "$time_part" ]]; then
    echo "${norm_date}T${start_of_day}"
    return 0
  fi

  #echo "DEBUG: __is_time_or_offset"
  local kind="$(__is_time_or_offset "$time_part")" || return 1
  case "$kind" in
    TIME)
      local norm=""
      norm="$(__normalize_time "$time_part")" || return 1
      echo "${norm_date}T${norm:0:5}"
      return 0
      ;;
    OFFSET)
      local norm_offset=""
      norm_offset=$(_add_offset_to_datetime "${norm_date}T${start_of_day}" "$time_part")
      echo "$norm_offset"
      return 0
      ;;
    *)
      echo "ERROR: Kunde inte tolka tid/offset: $time_part"
      return 1
      ;;
  esac

  #echo "DEBUG: Ingen tolkning lyckades"
  return 1
}


#
# Omvandlar namngivna veckodagar till format YYY-MM-DDThh:mm
# Input: måndag, monday.... idag, imorgon => 2025-06-02T08:00
#
# OBS: Om nuvarande datum är samma dag som man omnämner här, så läggs 7 dagar till
# Så på en söndag, så får man inte dagens datum tillbaka, man får datumet som ligger 7 dagar in i framtiden
#
function __parse_namegiven_day() {
  local input="$1"
  local start_of_day=$(__task_get_config "TASK_START_OF_DAY")

  case "${input,,}" in  # små bokstäver för jämförelse
    today | idag )
      date +"%Y-%m-%dT${start_of_day}"
      return 0
      ;;
    tomorrow | imorgon | tom | tomorow )
      date -d "tomorrow" +"%Y-%m-%dT${start_of_day}"
      return 0
      ;;
  esac

  # -- om inte today eller imorgon, tolka som dag-namn --
  local normNamedDays=$(__normalize_day "$input")

  local today_num
  today_num=$(date +%w)
  local input_num
  input_num=$(LC_TIME=en_US.UTF-8 date -d "$normNamedDays" +%w 2>/dev/null) || {
    echo "ERROR: Kunde inte tolka veckodag: $input" >&2
    return 1
  }

  local offset_days=0
  if [[ "$input_num" -eq "$today_num" ]]; then
    offset_days=7
  elif [[ "$input_num" -lt "$today_num" ]]; then
    offset_days=$((7 - today_num + input_num))
  else
    offset_days=$((input_num - today_num))
  fi

  local result
  result=$(date -d "+$offset_days days" +%Y-%m-%d)
  echo "${result}T${start_of_day}"
}

#@ Tolkar 'now', 'nu' eller enbart en offset till ISO-format YYYY-MM-DDTHH:MM
function __parse_now_time() {
  local input="$*"
  input="$(__trim "$input")"

  local base=""
  local offset=""

  # --- Fall 1: now / nu / now +offset ---
  if [[ "$input" =~ ^(now|nu)( .+)?$ ]]; then
    base="$(date +"%Y-%m-%dT%H:%M")"
    offset="${input#* }"
    [[ "$input" == "$offset" ]] && offset=""

  # --- Fall 2: enbart offset ---
  elif [[ "$(__is_time_or_offset "$input")" == "OFFSET" ]]; then
    base="$(date +"%Y-%m-%dT%H:%M")"
    offset="$input"

  # --- Fall 3: okänt format ---
  else
    __log_error "ERROR: Ogiltigt värde för __parse_now_time: '$input'"
    return 1
  fi

  # --- Hantera offset om den finns ---
  if [[ -n "$offset" ]]; then
    if [[ "$(__is_time_or_offset "$offset")" == "OFFSET" ]]; then
      __add_offset_to_datetime "$base" "$offset"
      return $?
    else
      __log_error "ERROR: Offset-del kunde inte tolkas: '$offset'"
      return 1
    fi
  fi

  echo "$base"
}


## Funktion: __normalize_datetime_iso
# Normaliserar datum+(tid/offset) till ISO-format YYYY-MM-DDThh:mm
# Inparameter: 1 eller 2 strängar (datum [tid|offset])
# Stöder:
#   - ren tid: HH:MM, HHMM, HH.MM → använder dagens datum
#   - namngivna dagar (måndag..söndag), idag/nu, imorgon
#   - numeriska datumformat: YYYY-MM-DD, YY-MM-DD, YYYY/MM/DD, MMDD
#   - offset: +Xm, +Yh, +YhZm, etc → läggs på angivet tid eller default start_of_day
#
# Om ingen ingen tid anges, anta att det är default start av dagen (08:00)
# Returns: YYYY-MMM-DDThh:mm
#
function __normalize_datetime() {
  local date_part time_part norm_date norm_time default_start offset_expr

  # --- Dela upp parametern(a) ---
  if [[ $# -eq 1 ]]; then
    IFS=' ' read -r date_part time_part <<< "$1"
   elif [[ $# -eq 2 ]]; then
     date_part="$1"; time_part="$2"
   else
     echo "ERROR: Fel antal parametrar: förväntar 1 eller 2 argument"
     return 1
  fi

  if __is_iso_datetime "$*" ; then
    local input
    input="$*"

    date_part="${input%%T*}"
    time_part="${input#*T}"

    norm_date="$(__normalize_date "$date_part")" || return 1
    norm_time="$(__normalize_time "$time_part")" || return 1

    echo  "${norm_date}T${norm_time}"
    return 0
  fi

  # --- Hantera fall: ENDAST tid eller ENDAST offset som första och enda param ---
  if [[ -z "$time_part" ]]; then
    local type
    type=$(__is_time_or_offset "$date_part") || type=""
    if [[ "$type" == "TIME" ]]; then
      # Endast tid => dagens datum
      time_part="$date_part"
      date_part="$(date +%Y-%m-%d)"
    elif [[ "$type" == "OFFSET" ]]; then
      # Endast offset => dagens datum + offset
      time_part="$date_part"
      date_part="$(date +%Y-%m-%d)"
    fi
  fi


  # --- DATUMDEL ---
  # Trimma whitespace och konvertera '/'  till '-'
  date_part="$(echo "$date_part" | tr -d '[:space:]' | sed 's|/|-|g')"

  # Namngiven dag (inkl. idag/nu/imorgon) har företräde
  if __is_namegiven_day "$date_part"; then
    local full="$(__normalize_day "$date_part")"
    norm_date="${full%%T*}"
  elif __is_valid_date "$date_part"; then
    norm_date="$(__normalize_date "$date_part")"
  else
    echo "ERROR: Ogiltigt datum: $date_part"
    return 1
  fi

  # --- TID/OFFSET ---
  # Hämta default start_of_day (hh:mm:ss)
  default_start="$(__task_get_config "TASK_START_OF_DAY" 2>/dev/null || echo "00:00:00")"
  default_start="${default_start%%:*}:${default_start#*:}:00"

  if [[ -z "$time_part" ]]; then
    # Inget angivet → default start
    norm_time="${default_start:0:5}"
  else
    # Rensa whitespace
    time_part="$(echo "$time_part" | tr -d '[:space:]')"
    # Offset börjar med '+' eller enbart siffror+m
    if [[ "$time_part" =~ ^\+ ]]; then
      offset_expr="$(__normalize_offset "$time_part")" || return 1
      norm_time="$(LC_TIME=en_US.UTF-8 date -d "${norm_date} ${default_start} ${offset_expr}" +"%H:%M")"
    else
      # Icke-offset → tolka som tid eller implicit offset utan '+'
      local ttype
      ttype=$(__is_time_or_offset "$time_part") || ttype=""
      if [[ "$ttype" == "OFFSET" ]]; then
        offset_expr="$(__normalize_offset "+$time_part")" || return 1
        norm_time="$(LC_TIME=en_US.UTF-8 date -d "${norm_date} ${default_start} ${offset_expr}" +"%H:%M")"
      else
        # Tolkning som tid (HH:MM, HHMM, HH.MM)
        norm_time="$(__normalize_time "$time_part")"
        norm_time="${norm_time:0:5}"
      fi
    fi
  fi

  # --- Skriv ut ISO-format ---
  echo "${norm_date}T${norm_time}"
}


# Tar emot en sträng och gör sitt absolut bästa att tolka det som en datum
# Return: YYYY-MM-DD
function __normalize_date() {
  local input="$*"

  # Ta bort blanksteg och ersätt eventuella snedstreck med bindestreck
  input="$(echo "$input" | tr -d '[:space:]' | sed 's|/|-|g')"

  # Matcha mot mönster YYYY-MM-DD eller YY-MM-DD, 8+2 eller 6+2 tecken
  if [[ "$input" =~ ^([0-9]{2,4})-([0-9]{2})-([0-9]{2})$ ]]; then
    # Validera datumet med GNU date
    if date -d "$input" "+%Y-%m-%d" >/dev/null 2>&1; then
      # Returnera som ISO-format
      date -d "$input" "+%Y-%m-%d"
    else
      #echo "Ogiltigt datum: $input"
      return 1
    fi
  # Matcha mot mönster YYYYMMDD eller YYMMDD, 8 eller 6
  elif [[ "$input" =~ ^([0-9]{2,4})([0-9]{2})([0-9]{2})$ ]]; then
    # Validera datumet med GNU date
    if date -d "$input" "+%Y-%m-%d" >/dev/null 2>&1; then
      # Returnera som ISO-format
      date -d "$input" "+%Y-%m-%d"
    else
       #echo "Ogiltigt datum: $input" >&2
      return 1
    fi
  # Matcha mot mönster MM-DD, 4+1
  elif [[ "$input" =~ ^([0-9]{2})-([0-9]{2})$ ]]; then
    # Validera datumet med GNU date
    local current_year=$(date +%Y)
    local comp_date="${current_year}-${input}"
    if date -d "$comp_date" "+%Y-%m-%d" >/dev/null 2>&1; then
      # Returnera som ISO-format
      date -d "$comp_date" "+%Y-%m-%d"
    else
      # echo "Ogiltigt datum: $input"
      return 1
    fi
  # Matcha mot mönster MMDD, 4 tecken
  elif [[ "$input" =~ ^([0-9]{2})([0-9]{2})$ ]]; then
    # Validera datumet med GNU date
    local current_year=$(date +%Y)
    local comp_date="${current_year}${input}"
    if date -d "$comp_date" "+%Y-%m-%d" >/dev/null 2>&1; then
      # Returnera som ISO-format
      date -d "$comp_date" "+%Y-%m-%d"
    else
      # echo "Ogiltigt datum: $input" >&2
      return 1
    fi

  else
    # echo "Fel format, förväntade YYYY-MM-DD (ev. med / istället för -)" >&2
    return 1
  fi
}

function __normalize_time() {
  local input="$1"

  # Ta bort inline-kommentarer och trimma mellanslag
  input="${input%%#*}"
  input="$(echo "$input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

  # Rensa bort kolon och punkt: t.ex. 13.30 → 1330
  local numeric="${input//[:.]/}"
  numeric="${numeric//[^0-9]/}"

  # Kontrollera att det är numeriskt
  if [[ ! "$numeric" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Ogiltigt tidsformat: $input"
    return 1
  fi

  # Bestäm längd och sätt maxgräns
  local maxval maxstr
  case ${#numeric} in
    6)
      maxval=235959
      maxstr="23:59:59"
      ;;
    4)
      maxval=2359
      maxstr="23:59"
      ;;
    3)
      maxval=959
      maxstr="09:59"
      ;;
    1|2)
      maxval=23
      maxstr="23:00"
      ;;
    *)
      echo "ERROR: Oväntad tidslängd: $input"
      return 1
      ;;
  esac

  # Konvertera till decimal (skydda mot oktaltolkning)
  numeric=$((10#$numeric))

  if (( numeric > maxval )); then
    echo "ERROR: Ogiltig tid: $input – 24h tid tillåter upp till $maxstr"
    return 1
  fi

  # Formatera till HH:MM (utan sekunder)
  case ${#numeric} in
    1|2)
      printf "%02d:00\n" "$numeric"
      ;;
    3)
      printf "0%s:%s\n" "${numeric:0:1}" "${numeric:1:2}"
      ;;
    4)
      printf "%s:%s\n" "${numeric:0:2}" "${numeric:2:2}"
      ;;
    6)
      printf "%s:%s\n" "${numeric:0:2}" "${numeric:2:2}"
      ;;
  esac
}


# Normaliserar strängar för tidsangivelse/klocka
# Stöd för att säga saker som
#  > 12:30(:00), 12.30(.00), 1230(00) och alla normaliseras till 12:30:00
#  > 10 som normaliseras till 10:00:00
#  > 1 som normaliseras till 01:00:00
#
# Ger fel tillbaka om man försöker gå över 23:59 eller 23:59:59
#
# %% Test: testcases/normalize_time.test

# Noramliserar strängar för tidsåtgång
# Stöd för att säga saker som
#  > 20  20m 20min  20minutes  20minuter         -> 20 minutes
#  > 1h  1hr 1hour 1hours 1t 1tim 1timme 1timmar -> 1 hour
#  %% Testcase: testcases/normalize_duration.test
function __normalize_duration() {
  local dur="$1"

  # Normalisera duration
  if [[ "$dur" =~ ^[0-9]+$ ]]; then
    # Ex: "20" -> "20 minutes"
    dur="${dur} minutes"
  elif [[ "$dur" =~ ^([0-9]+)(m|min|minutes|minuter)$ ]]; then
    # Ex: "20m" eller "20min" -> "20 minutes"
    dur="${BASH_REMATCH[1]} minutes"
  elif [[ "$dur" =~ ^([0-9]+)(h|hr|hour|hours|t|tim|timme|timmar)?$ ]]; then
    # Ex: "1h", "1hr", "1hour" -> "1 hour"
    dur="${BASH_REMATCH[1]} hour"
  fi

  # Validera duration
  if ! date -d "1970-01-01 00:00:00 + $dur" >/dev/null 2>&1; then
    echo "Ogiltig duration: \"$dur\" – försök t.ex. 20min, 1h, 90minutes"
    return 1
  fi

  echo "$dur"
}


# Normaliserar time-offset strängar
# Stöd för t.ex. +2h30m, 1h, 15min, +45m, och även 5
# Vi behöver inte ha +-tecknet
#
# Normaliseringen hanterar olika stavningar av svenska och engelska mint/timme
# sv: (t, tim, timme, timmar)   eng: (h, hr, hour, hours)
# sv: (m, min, minut, minuter)  eng: (m, min, minutes)
# Default enhet är minuter, så 5 tolkas som offset +5 minutes
#
# Vi stöder även att man inte skriver plus (+) framför
# Vi hanterar felcheck på enheten av tiden
#
# Returns:
#
# %%Testcase: testcases/normalize_offset.test
function __normalize_offset() {
  local raw="$1"
  local result=""

  raw="${raw#+}"  # ta bort eventuell inledande '+'

  while [[ -n "$raw" ]]; do
    if [[ "$raw" =~ ^([0-9]+)(h|hr|hour|hours|t|tim|timme|timmar|m|min|minuter|minutes?) ]]; then
      local num="${BASH_REMATCH[1]}"
      local unit="${BASH_REMATCH[2]}"
      raw="${raw#${BASH_REMATCH[0]}}"

      case "$unit" in
        h|hr|hour|hours|t|tim|timme|timmar)
          result="$result ${num} hours"
          ;;
        m|min|minut|minuter|minutes)
          result="$result ${num} minutes"
          ;;
        *)
          __log_error "Ogiltig enhet: $unit"
          return 1
          ;;
      esac

    elif [[ "$raw" =~ ^([0-9]+)$ ]]; then
      result="$result ${BASH_REMATCH[1]} minutes"
      raw=""
    else
      __log_error "Kunde inte tolka offset-del: '$raw'"
      return 1
    fi
  done

  local tr_res
  tr_res=$(__trim "$result")
  echo "$tr_res"
}

function __normalize_day() {
  local input="$1"
  case "$input" in
    #----#
    måndag)  echo "monday" ;;
    tisdag)  echo "tuesday" ;;
    onsdag)  echo "wednesday" ;;
    torsdag) echo "thursday" ;;
    fredag)  echo "friday" ;;
    lördag)  echo "saturday" ;;
    söndag)  echo "sunday" ;;
    #----#
    monday)    echo "monday" ;;
    tuesday)   echo "tuesday" ;;
    wednesday) echo "wednesday" ;;
    thursday)  echo "thursday" ;;
    friday)    echo "friday" ;;
    saturday)  echo "saturday" ;;
    sunday)    echo "sunday" ;;
    #----#
    mån)  echo "monday" ;;
    tis)  echo "tuesday" ;;
    ons)  echo "wednesday" ;;
    tor)  echo "thursday" ;;
    tors) echo "thursday" ;;
    fre)  echo "friday" ;;
    lör)  echo "saturday" ;;
    sön)  echo "sunday" ;;
    #----#
    mon)    echo "monday" ;;
    tue)    echo "tuesday" ;;
    tues)   echo "tuesday" ;;
    wed)    echo "wednesday" ;;
    wednes) echo "wednesday" ;;
    thu)    echo "thursday" ;;
    thurs)  echo "thursday" ;;
    fri)    echo "friday" ;;
    sat)    echo "saturday" ;;
    satur)  echo "saturday" ;;
    sun)    echo "sunday" ;;
    #----#
    *) echo "ERROR" ;;
  esac
}


function __is_date_string() {
  local input="$1"
  local first="${input%% *}"

  # Konvertera till ISO-format med normalisering
  local date_part
  date_part=$(__normalize_date "$first") || return 1

  # Kontroll: är det ett giltigt datum?
  if date -d "$date_part" >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

function __is_only_date_string() {
  local input="$*"

  echo "DEBUG: __is_only_date_string"
  # Trimma eventuell whitespace
  input=$(__trim "$input")

  # Format: YYYYMMDD eller YYMMDD eller MMDD
  if [[ "$input" =~ ^[0-9]{6,8}$ ]]; then
    echo "DEBUG: Matchar YYYYMMDD eller YYMMDD eller MMDD"
    __is_valid_date "$input" || return 1 && return 0
  fi

  # Format: MMDD
  if [[ "$input" =~ ^[0-9]{4}$ ]]; then
    echo "DEBUG: Matchat MMDD"
    __is_valid_date "$input" || return 1 && return 0
  fi

  # Format YYYY-MM-DD eller YYYY/MM/DD
  if [[ "$input" =~ ^[0-9]{4}[-/][0-9]{2}[-/][0-9]{2}$ ]]; then
    echo "DEBUG: Matchat mot YYYY/MM/DD"
    __is_valid_date "$input" || return 1 && return 0
  fi

  # Matchar YY-MM-DD eller YY/MM/DD
  if [[ "$input" =~ ^[0-9]{2}[-/][0-9]{2}[-/][0-9]{2}$ ]]; then
    echo "DEBUG: Matcha mot YY/MM/DD"
    __is_valid_date "$input" || return 1 && return 0
  fi

  # Matchar MM-DD eller MM/DD
  if [[ "$input" =~ ^[0-9]{2}[-/][0-9]{2}$ ]]; then
    echo "DEBUG: matcha mot MM/DD"
    __is_valid_date "$input" || return 1 && return 0
  fi

  echo "DEBUG: Matchat mot inget"
  return 1
}

# Avgör om en sträng har något med datum att göra eller inte
# Return 0 om strängen anses vara datum baserad
# Return 1 om strängen anses vara t ex namn, beskrivning, etc
function __is_date_based() {
  local input="$*"
  input="$(__trim "$input")"
  local lowercase=""
  lowercase="${input,,}"
  # Om tom, returnera false
  [[ -z "$lowercase" ]] && return 1

  # Kolla om den matchar något tidsrelaterat
  if __is_namegiven_day "$lowercase"; then return 1; fi
  if __is_valid_date "$lowercase" &> /dev/null; then return 1; fi
  if __is_time_or_offset "$lowercase" &>/dev/null; then return 1; fi
  if [[ "$" =~ ^(now|nu)$ ]]; then return 1; fi

  # Om inget av ovan: det är sannolikt en beskrivning
  return 0
}


function __is_valid_date() {
  local input="$1"
  local lowercase=""
  lowercase="${input,,}"

  if [[ -z "$lowercase" ]]; then
    return 1
  fi

  date_part=$(__normalize_date "$lowercase")
  rc=$?

  if [[ "$rc" != "0" ]] ; then
      echo "ERROR: __is_valid_date: Ogitigt datum: $input" ; return 1
      return $rc
  fi
  return 0
}

# Verfierar om det är en sträng med datum+tid
function __is_valid_datetime() {
  local input="$1"

  if [[ -z "$input" ]]; then
    return 1
  fi


  if __normalize_datetime "$input" &> /dev/null; then
    return 0
  else
    return 1
  fi
}

function __is_time_or_offset() {
  local input="$*"

   # Trimma och splitta på första mellanslag
  part1="${input%% *}"
  part2="${input#* }"
  [[ "$part1" == "$part2" ]] && part2=""

  # 1. Om det finns två delar: kontrollera om första är datum/datetime och andra en offset
  if [[ -n "$part2" ]]; then
    if [[ "$part1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{2}:[0-9]{2})?$ ]] &&
       [[ "$part2" =~ ^\+?[0-9]+([hmt]|(h|hr|hour|tim|timme|timmar|m|min|minuter|minutes))+$ ]]; then
      echo "OFFSET"
      return 0
    fi
  fi


  # 1. Enbart datum eller datum + tid (med eller utan T)
  if [[ "$input" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}([T ][0-9]{2}:[0-9]{2})?$ ]]; then
    echo "TIME"
    return 0
  fi

  # 2. Datum (med eller utan tid) + offset, inklusive +1h30m
  if [[ "$input" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{2}(:| )[0-9]{2})?[[:space:]]+\+?([0-9]+(h|hr|hour|tim|timme|timmar)|[0-9]+(m|min|minuter|minutes)){1,2}$ ]]; then
    echo "OFFSET"
    return 0
  fi

  # 3. Tidformat (HH:MM, HH.MM) + offset
  if [[ "$input" =~ ^([0-9]{1,2}:[0-9]{2}|[0-9]{3,4}|[0-9]{1,2}\.[0-9]{2})[[:space:]]+\+?[0-9]+(h|hr|hour|tim|timme|timmar|m|min|minuter|minutes)+$ ]]; then
    echo "OFFSET"
    return 0
  fi

  # 4. Endast tid: HH:MM, HH.MM
  if [[ "$input" =~ ^([0-9]{1,2}(:| )[0-9]{2}|[0-9]{1,2}\.[0-9]{2})$ ]]; then
    echo "TIME"
    return 0
  fi

  # 5. 4-siffrig tid: HHMM
  if [[ "$input" =~ ^[0-9]{4}$ ]]; then
    echo "TIME"
    return 0
  fi

  # 6. Offset enbart: t.ex. +1h30m, 30m, 1h
  if [[ "$input" =~ ^\+?([0-9]+(h|hr|hour|tim|timme|timmar|m|min|minuter|minutes)){1,}$ ]]; then
    echo "OFFSET"
    return 0
  fi

  # 7. Enbart siffror: t.ex. "30" = 30 minuter
  if [[ "$input" =~ ^[0-9]{1,3}$ ]]; then
    echo "OFFSET"
    return 0
  fi

  # 8. Fel
  echo ""
  return 1
}


# Avgör om en sträng är någon form av en dag på alla dess former
#    Svenska och engelska veckodags namn
#    idag, imorgon, nu
#    today, tomorrow, tomorow
function __is_namegiven_day() {
  local param="$1"

  case "$param" in
     # -- konceptuell datum
     idag|today)                   return 0 ;;
     imorgon|tomorrow|tom|tomorow) return 0 ;;
  esac

   local day
   day=$(__normalize_day $param)
   case "$day" in
     # -- konceptuell datum
     monday|tuesday|wednesday|thursday|friday|saturday|sunday) return 0 ;;
   esac

   return 1
}

function __trim() {
  local input="$1"
  # Ta bort leading/trailing whitespace
  input="${input#"${input%%[![:space:]]*}"}"  # vänster trim
  input="${input%"${input##*[![:space:]]}"}"  # höger trim
  echo "$input"
}


# Tar en sträng i format
# Param1: YYY-MM-DD
# Param2: HH:MM
# Return: YYY-MM-DDTHH:MM
function __combine_datetime() {
 local input="$*"
  local part1=""
  local part2=""
  input=$(__trim "$input")

  part1="${input%% *}"
  part1=$(__trim "$part1")

  part2="${input#* }"
  part2=$(__trim "$part2")

  # Om det inte fanns något mellanslag, part2 blir samma som part1 => nolla den
  if [[ "$part1" == "$part2" ]]; then
    part2=""
  fi

  echo "${part1}T${part2}"
}


# split_datetime “INPUT”
# Läser in INPUT i format som t.ex.
#   2025-03-30T08:30, 20250330 0945, 03 30 09 45 eller bara 30 09 45
# Skriver ut normaliserat ISO-datum + tid: "YYYY-MM-DD HH:MM"
# Användning:
#   read -r date time < <(__split_datetime "2025-05-04T08:30")
#   read -r date time < <(__split_datetime "2025-05-04 08:30")
split_datetime() {
  local input="$1"

  # Steg 1: fånga datumdelen + timme/minut
  if [[ "$input" =~ ^(.+?)[T[:space:]]?([0-9]{2})[[:space:]:]?([0-9]{2})$ ]]; then
    local datePart="${BASH_REMATCH[1]}"
    local hh="${BASH_REMATCH[2]}"
    local mm="${BASH_REMATCH[3]}"

    # Steg 2: ta bort allt utom siffror i datumdelen
    local cleanDate="${datePart//[^0-9]/}"
    local len=${#cleanDate}

    # Hämta dagens år och månad (Europa/Stockholm)
    local currentYear currentMonth
    currentYear=$(TZ=Europe/Stockholm date +%Y)
    currentMonth=$(TZ=Europe/Stockholm date +%m)

    local year month day

    # Steg 3: tolka beroende på hur många siffror vi har kvar
    case "$len" in
      8)  # ÅÅÅÅMMDD
          year="${cleanDate:0:4}"
          month="${cleanDate:4:2}"
          day="${cleanDate:6:2}"
          ;;
      6)  # YYMMDD → prefixa ’20’
          year="20${cleanDate:0:2}"
          month="${cleanDate:2:2}"
          day="${cleanDate:4:2}"
          ;;
      4)  # MMDD → dagens år
          year="$currentYear"
          month="${cleanDate:0:2}"
          day="${cleanDate:2:2}"
          ;;
      2)  # DD → dagens år & månad
          year="$currentYear"
          month="$currentMonth"
          day="${cleanDate}"
          ;;
      *)
          echo "Error: ogiltigt datumformat – '$datePart'"
          return 1
          ;;
    esac

    # Steg 4: skriv ut med nollutfyllnad
    #printf "%04d-%02d-%02d %02d:%02d\n" "$year" "$month" "$day" "$hh" "$mm"

    echo "${year}-${month}-${day}T${hh}:${mm}"
    return 0
  else
    #echo "Error: kunde inte parsa '$input'" >&2
    return 1
  fi
}


function __add_offset_to_datetime() {
  local datetime="$1"
  local offset="$2"

  if [[ -z "$datetime" || -z "$offset" ]]; then
    echo "❌ Användning: __add_offset_to_datetime <datetime> <offset>" >&2
    return 1
  fi


  # Ersätt ev. "T" med mellanslag så GNU date förstår
  local normDateTime="${datetime//T/ }"
  local normOffset=$(__normalize_offset $offset)

  #echo "DT: $normDateTime"
  #echo "OF: $normOffset"
  #echo "ST: LC_TIME=sv_SE.UTF-8 date -d '$normDateTime $normOffset' +'%Y-%m-%dT%H:%M'"

  # Konvertera
  local result
  result=$(LC_TIME=sv_SE.UTF-8 date -d "$normDateTime $normOffset" +"%Y-%m-%dT%H:%M") || {
    echo "ERROR: Kunde inte utöka $datetime med ytterligare $offset"
    return 1
  }

  echo "$result"
}


# Make sure that we have T between stuff
function __is_iso_datetime() {
  local input="$*"

  local regex1 regex2 regex3 regex4

  # Matcha: datumdel (2–8 siffror, med eller utan - eller /), följt av T, följt av HHMM eller HH:MM
  regex1="^[0-9]{2,4}[-/]?[0-9]{2}[-/]?[0-9]{2}T[0-9]{2}(:?[0-9]{2})$"

  # t.ex. 20230403T0900 eller 230403T0900
  regex2="^[0-9]{6,8}T[0-9]{4}$"

  # t.ex. MMDDT0900 → implicit år
  regex3="^[0-9]{4}T[0-9]{4}$"

  # t.ex. DDT0900 → implicit år & månad
  regex4="^[0-9]{2}T[0-9]{4}$"

  if [[ "$input" =~ $regex1 ]]; then
    return 0
  elif [[ "$input" =~ $regex2 ]]; then
    return 0
  elif [[ "$input" =~ $regex3 ]]; then
    return 0
  elif [[ "$input" =~ $regex4 ]]; then
    return 0
  else
    return 1
  fi
}

function __is_datetime() {
  local input="$*"

  local regex1 regex2 regex3 regex4

  # Matcha: datumdel med valfria bindestreck eller snedstreck + [T ]? + tid
  regex1="^[0-9]{2,4}[-/]?[0-9]{2}[-/]?[0-9]{2}[T ]?[0-9]{2}(:?[0-9]{2})$"

  # t.ex. 20230403T0900 eller 230403 0900
  regex2="^[0-9]{6,8}[T ]?[0-9]{4}$"

  # t.ex. MMDDT0900 eller MMDD 0900
  regex3="^[0-9]{4}[T ]?[0-9]{4}$"

  # t.ex. DDT0900 eller DD 0900
  regex4=" ^[0-9]{2}[T ]?[0-9]{4}$"

  if [[ "$input" =~ $regex1 ]]; then
    return 0
  elif [[ "$input" =~ $regex2 ]]; then
    return 0
  elif [[ "$input" =~ $regex3 ]]; then
    return 0
  elif [[ "$input" =~ $regex4 ]]; then
    return 0

  fi

  return 1
}

