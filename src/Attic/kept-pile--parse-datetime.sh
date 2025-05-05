#!/usr/bin/env sh

# function __normalize_date__nope() {
#   local input="$1"
#   local current_year
#   current_year=$(date +%Y)

#   # Rensa whitespace och byt / mot -
#   input="$(echo "$input" | tr -d '[:space:]' | sed 's|/|-|g')"

#   # YYYY-MM-DD eller YYYY/MM/DD
#   if [[ "$input" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})$ ]]; then
#     if date -d "$input" "+%Y-%m-%d" >/dev/null 2>&1; then
#       date -d "$input" "+%Y-%m-%d"
#       return 0
#     fi

#   # MM-DD
#   elif [[ "$input" =~ ^([0-9]{2})-([0-9]{2})$ ]]; then
#     local month="${BASH_REMATCH[1]}"
#     local day="${BASH_REMATCH[2]}"
#     if date -d "$current_year-$month-$day" "+%Y-%m-%d" >/dev/null 2>&1; then
#       date -d "$current_year-$month-$day" "+%Y-%m-%d"
#       return 0
#     fi

#   # MMDD (fyra siffror)
#   elif [[ "$input" =~ ^([0-9]{4})$ ]]; then
#     local month="${input:0:2}"
#     local day="${input:2:2}"
#     if date -d "$current_year-$month-$day" "+%Y-%m-%d" >/dev/null 2>&1; then
#       date -d "$current_year-$month-$day" "+%Y-%m-%d"
#       return 0
#     fi
#   fi

#   echo "❌ Ogiltigt datumformat: $input" >&2
#   return 1
# }

function __add_offset_to_datetime_tst() {
  local datetime="$1"
  local offset="$2"

  if [[ -z "$datetime" || -z "$offset" ]]; then
    echo "❌ Användning: __add_offset_to_datetime <datetime> <offset>" >&2
    return 1
  fi

  # Ersätt ev. 'T' med mellanslag för GNU date
  local datetime_fixed="${datetime//T/ }"

  # Kontrollera att det går att tolka basdatumet
  if ! date -d "$datetime_fixed" >/dev/null 2>&1; then
    echo "❌ Ogiltigt datum: $datetime" >&2
    return 1
  fi

  # Lägg på offset
  local result
  result=$(LC_ALL=en_US.UTF-8 date -d "$datetime_fixed $offset" +"%Y-%m-%dT%H:%M") || {
    echo "❌ Kunde inte addera offset: $offset till $datetime" >&2
    return 1
  }

  echo "$result"
}

__add_offset_to_datetime_xx() {
  local datetime="$1"
  local offset="$2"

  if [[ -z "$datetime" || -z "$offset" ]]; then
    echo "❌ Användning: __add_offset_to_datetime <datetime> <offset>" >&2
    return 1
  fi

  local norm_datetime=$(__noramlize_date)

  # Normalisera offset: ta bort plustecken, konvertera units
  local norm_offset=$(__normalize_offset $offset)

  # Testa om datumet är giltigt
  if ! date -d "$datetime_fixed" >/dev/null 2>&1; then
    echo "❌ Ogiltigt datum: $datetime" >&2
    return 1
  fi

  # Lägg på offset
  local result
  result=$(LC_ALL=en_US.UTF-8 date -d "$datetime_fixed $norm_offset" "+%Y-%m-%dT%H:%M") || {
    echo "❌ Kunde inte addera offset: $offset ($norm_offset) till $datetime" >&2
    return 1
  }

  echo "$result"
}


function __parse_datetime__deprecated() {
  local date_str="$1"        # was: basse="$1"
  local time_or_offset="$2"

  echo "HEJ 1"
  # Om första parametern är now, så skapa en normaliserad tidstämpel
  if [[ "$date_str" == "now" ]] || [[ "$date_str" == "nu" ]] ; then
    if [[ -z "$time_or_offset" ]] ; then
      __parse_now_time "$base"
      return 0
    fi
  fi


  echo "HEJ 1"
  # Om första parametern är today, så skapa en normaliserad tidstämpel
  if __is_namegiven_day "$base" ; then
     if [[ -z "$time_or_offset" ]] ; then
       __parse_day_str "$base"
       return 0
     fi
  fi

  echo "HEJ 2"
  # Om bara offset anges, tolka som "nu + offset"
  if [[ "$(__is_time_or_offset)" == "OFFSET" ]] ; then
    time_or_offset="$base"
    base="now"
  fi


    echo "HEJ 3"
  if [[ -z "$base" ]] ; then
    __log_error "Ange minst en tidpunkt, t.ex. 'måndag 10' eller 'fredag 13:00' eller '04-10 08:30'"
    return 1
  fi


  echo "HEJ 4"
  # Default start tid för tasks, kan sättas som miljövariabel i t ex ~/.bashrc
  local start_of_day=$(__task_get_config "TASK_START_OF_DAY")
  local current_year=$(date +%Y)
  local base_day=""
  local base_time=""
  local base_date=""

  echo "HEJ 5"
  # Steg 1: Tolka datumdelen
  case "$base" in
    # -- konceptuell datum
    nu|now)                      base_date="now" ;;
    idag|today)                  base_date=$(date +%Y-%m-%d) ;;
    imorgon|morrow|tom|tomorrow) base_date=$(date -d tomorrow +%Y-%m-%d) ;;
    #-- Exakt datum
    *)
      # Normalisera till ISO-datumformat
      if [[ "$base" =~ ^[0-9]{4}[-/][0-9]{1,2}[-/][0-9]{1,2}$ ]]; then
        base_time=$(echo "$base" | sed 's|/|-|g')
      elif [[ "$base" =~ ^[0-9]{1,2}[-/][0-9]{1,2}$ ]]; then
        base_time="${current_year}-$(echo "$base" | sed 's|/|-|')"
      else
        base_day=$(__normalize_day "$base")
        if [[ "$base_day" == "ERROR" ]]; then
          __log_error "Felaktigt dagsformat: '$base'"
          return 1
        fi
        base_time=$(LC_TIME=en_US.UTF-8 date -d "$base_day" "+%Y-%m-%d") || {
          __log_error "Kunde inte tolka dagsnamn: $base"
          return 1
        }
      fi
      ;;
  esac

  # Steg 2: Lägg till klockslag eller offset
  if [[ -z "$time_or_offset" ]]; then
    # Bara datum -> defaulta till start av kontorsdagen
    echo "${base_time}T${start_of_day}"
    return 0
  fi

  # Försök tolka tid eller offset
  if [[ "$time_or_offset" =~ ^[0-9:.]+$ ]]; then
    local normalized
    normalized=$(__normalize_time "$time_or_offset") || return 1
    echo "${base_time}T${normalized:0:5}"
    return 0
  else
    local offset
    # Använd start-of-day tid istället för midnatt
    #local offset_start="${base_time}T${start_of_day}"

    #local iso
    iso=$(LC_TIME=en_US.UTF-8 date -d "$base_time $offset" "+%Y-%m-%dT%H:%M") || {
      __log_error "Kunde inte tolka: $base_time $offset"
      return 1
    }

    #local iso
    #iso=$(LC_TIME=en_US.UTF-8 date -d "$offset_start $offset" "+%Y-%m-%dT%H:%M") || {
    #  __log_error "Kunde inte tolka: $offset_start + $offset"
    #  return 1
    #}

    echo "$iso"
    return 0
  fi
}


function __parse_namegiven_dayxxx() {
  local input="$1"
  local start_of_day=$(__task_get_config "TASK_START_OF_DAY")

  local normNamedDays=$(__normalize_day $input)

  case "${normNamedDays,,}" in  # gemener för jämförelse
    monday | tuesday | wednesday | thursday | friday | saturday | sunday )
      # date -d "$normNamedDay" +"%FT${start_of_day}"
      LC_TIME=en_US.UTF-8 date -d "$normNamedDays" "+%Y-%m-%dT${start_of_day}"

      return 0
      ;;
  esac


  case "${input,,}" in  # gemener för jämförelse
    today | idag )
      date +"%FT${start_of_day}"
      ;;
    tomorrow | imorgon | tom | tomorow )
      date -d "tomorrow" +"%FT${start_of_day}"
      ;;
    *)
      # Försök tolka som ett datum
      LC_TIME="en_US.UTF-8" date -d "$input" +"%FT${start_of_day}" 2>/dev/null || {
        echo "❌ Kunde inte tolka datum: $input" >&2
        return 1
      }
      ;;
  esac
}

function __parse_namegiven_dayxx() {
  local input="$1"
  local start_of_day=$(__task_get_config "TASK_START_OF_DAY")
  local normNamedDays=$(__normalize_day "$input")

  # Get today's weekday number (0=sunday, ..., 6=saturday)
  local today_num=$(date +%w)

  # Get input weekday number
  local input_num=$(LC_TIME=en_US.UTF-8 date -d "$normNamedDays" +%w 2>/dev/null) || {
    echo "ERROR: Kunde inte tolka veckodag: $input" >&2
    return 1
  }

  echo "ND: $normNamedDays"
  echo "IN: $input_num"

  # Om dagen är samma som idag, lägg till +7 dagar
  local offset_days=0
  #
  #
  # if [[ "$input_num" -eq "$today_num" ]]; then
  #   offset_days=7
  # elif [[ "$input_num" -lt "$today_num" ]]; then
  #   offset_days=$((7 - today_num + input_num))
  # else
  #   offset_days=$((input_num - today_num))
  # fi

  # Beräkna datum
  local result
  result=$(date -d "+$offset_days days" +%Y-%m-%d)
  echo "${result}T${start_of_day}"
}

#@ Tolka ett datum
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
function __parse_datetimexx() {
  local date_part=""
  local time_part=""

  if [[ $# -eq 1 ]]; then
    # En parameter: försök splitta till datum + tid
    local result=$(__split_string "$*")

    date_part="${result%%T*}"
    time_part="${result#*T}"
  elif [[ $# -eq 2 ]]; then
    # Två separata argument: anta datum + tid
    date_part="$1"
    time_part="$2"
  else
    __log_error "Fel antal parametrar: förväntar 1 eller 2 argument"
    return 1
  fi

  # Kolla om det en namngiven dag
  if __is_namegiven_day "$date_part" ; then
    if [[ -z "$time_part" ]] ; then
      local today_date=""
      today_date=$(__parse_namegiven_day "$date_part")
      echo $today_date
      return 0
    else
     echo "xx"
    fi
  fi
}


#
# Param: en sträng
function __is_time_or_offset_deprecated() {
  local param="$1"

  # 1. Matchar explicita klockslag. ex (0)9:30 och (0)9.30
  if [[ "$param" =~ ^([0-9]{1,2}:[0-9]{2}|[0-9]{1,2}\.[0-9]{2})$ ]]; then
    echo "TIME"
    return 0

  # 2. Matchar heltal med exakt 4 siffror (ex: 1030 → TIME)
  elif [[ "$param" =~ ^[0-9]{3,4}$ ]]; then
    echo "TIME"
    return 0

  # 3. Matchar offset med + eller enhet
  elif [[ "$param" =~ ^(\+)?[0-9]+(h|hr|hour|t|tim|timme|timmar|m|min|minuter|minutes)?$ ]]; then
    echo "OFFSET"
    return 0

  # 4. Matchar rena tal (t.ex. 30, 90) → tolka som OFFSET
  elif [[ "$param" =~ ^[0-9]{1,3}$ ]]; then
    echo "OFFSET"
    return 0

  # 5. Annars fel
  else
    #echo "ERROR: kan inte tolka tidsangivelsen \"$param\"" >&2
    __log_error "ERROR: kan inte tolka tidsangivelsen \"$param\""
    return 1
  fi
}

function __is_time_or_offset() {
  local input="$1"

  # 1. Enbart datum eller datum + tid (med eller utan T)
  if [[ "$input" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}([T ][0-9]{2}:[0-9]{2})?$ ]]; then
    echo "TIME"
    return 0
  fi

  # 2. Datum (+ev. tid) + offset
  if [[ "$input" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{2}:[0-9]{2})?[[:space:]]+\+?[0-9]+(h|hr|hour|tim|timme|timmar|m|min|minuter|minutes)+$ ]]; then
    echo "OFFSET"
    return 0
  fi

  # 3. Tidformat (HH:MM, HH.MM) + offset
  if [[ "$input" =~ ^([0-9]{1,2}:[0-9]{2}|[0-9]{3,4}|[0-9]{1,2}\.[0-9]{2})[[:space:]]+\+?[0-9]+(h|hr|hour|tim|timme|timmar|m|min|minuter|minutes)+$ ]]; then
    echo "OFFSET"
    return 0
  fi

  # 4. Endast tid: HH:MM, HH.MM
  if [[ "$input" =~ ^([0-9]{1,2}:[0-9]{2}|[0-9]{1,2}\.[0-9]{2})$ ]]; then
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
  __log_error "ERROR: kan inte tolka tidsangivelsen \"$input\""
  return 1
}

function __is_time_or_offset__x2() {
  local input="$1"

  # 1. Matchar datum med eller utan tid (YYYY-MM-DD eller YYYY-MM-DDTHH:MM)
  if [[ "$input" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}([T ][0-9]{2}:[0-9]{2})?$ ]]; then
    echo "TIME"
    return 0
  fi

  # 2. Matchar "datum + offset" => t.ex. "2025-03-30 +1h30m" eller "2025-03-30T08:00 +45m"
  if [[ "$input" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{2}:[0-9]{2})?[[:space:]]+\+?[0-9]+(h|hr|hour|tim|timme|timmar|m|min|minuter|minutes)+$ ]]; then
    echo "OFFSET"
    return 0
  fi

  # 3. Enbart klockslag: 09:30 eller 9.30
  if [[ "$input" =~ ^([0-9]{1,2}:[0-9]{2}|[0-9]{1,2}\.[0-9]{2})$ ]]; then
    echo "TIME"
    return 0
  fi

  # 4. Exakt 4 siffror, t.ex. 0930 eller 2359 => TIME
  if [[ "$input" =~ ^[0-9]{4}$ ]]; then
    echo "TIME"
    return 0
  fi

  # 5. Matchar offset: "+1h", "1h30m", "+30m"
  if [[ "$input" =~ ^\+?[0-9]+(h|hr|hour|tim|timme|timmar|m|min|minuter|minutes)+$ ]]; then
    echo "OFFSET"
    return 0
  fi

  # 6. Enbart siffror utan enhet => tolkas som minuter (offset)
  if [[ "$input" =~ ^[0-9]{1,3}$ ]]; then
    echo "OFFSET"
    return 0
  fi

  # 7. Fångar t.ex. "1h30m", "+1h45m" osv
  if [[ "$input" =~ ^\+?([0-9]+(h|hr|hour|tim|timme|timmar|m|min|minuter|minutes)){2,}$ ]]; then
    echo "OFFSET"
    return 0
  fi

  # 8. Felhantering
  __log_error "ERROR: kan inte tolka tidsangivelsen \"$input\""
  return 1
}


function __is_time_or_offset_jnx() {
  local input="$1"
  local part1 part2

  echo "akjdsf"

  # Trimma och splitta på första mellanslag
  part1="${input%% *}"
  part2="${input#* }"
  [[ "$part1" == "$part2" ]] && part2=""

  # 0. Om strängen slutar på +
  #if [[ "$input" =~ ^\+?([0-9]+(h|hr|hour|tim|timme|timmar|m|min|minuter|minutes))+ ]]; then
 if [[ "$input" =~ ^\+?([0-9]+(h|hr|hour|tim|timme|timmar|m|min|minuter|minutes))+ ]]; then
    echo "OFFSET"
    return 0
  fi

  # 1. Om det finns två delar: kontrollera om första är datum/datetime och andra en offset
  if [[ -n "$part2" ]]; then
    if [[ "$part1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{2}:[0-9]{2})?$ ]] &&
       [[ "$part2" =~ ^\+?[0-9]+([hmt]|(h|hr|hour|tim|timme|timmar|m|min|minuter|minutes))+$ ]]; then
      echo "OFFSET"
      return 0
    fi
  fi

  # 2. Enbart ISO-format datum
  if [[ "$input" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "TIME"
    return 0
  fi

  # 3. ISO-format med tid
  if [[ "$input" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}$ ]]; then
    echo "TIME"
    return 0
  fi

  # 4. Vanliga tidsformat: 09:30, 0930, 9.30
  if [[ "$input" =~ ^([0-9]{1,2}:[0-9]{2}|[0-9]{4}|[0-9]{1,2}\.[0-9]{2})$ ]]; then
    echo "TIME"
    return 0
  fi

  # 5. Enbart offset, inklusive sammansatt
  if [[ "$input" =~ ^\+?[0-9]+(h|hr|hour|tim|timmar|m|min|minuter|minutes)+([0-9]+(m|min|minuter|minutes))?$ ]]; then
    echo "OFFSET"
    return 0
  fi

  # 6. Enbart tal tolkas som offset i minuter
  if [[ "$input" =~ ^[0-9]{1,3}$ ]]; then
    echo "OFFSET"
    return 0
  fi

  __log_error "ERROR: kan inte tolka tidsangivelsen \"$input\""
  return 1
}


function __is_time_or_offsetxxxxx() {
  local param="$1"

  # Ta bort extra whitespace
  param=$(__trim "$param")

  # 1. Matcha datum eller datum med tid (ISO-format)
  if [[ "$param" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "TIME"
    return 0
  elif [[ "$param" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}(T| )[0-9]{2}:[0-9]{2}$ ]]; then
    echo "TIME"
    return 0
  fi

  # 2. Matcha <datum> <offset> eller <datumTid> <offset>
  if [[ "$param" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}([T ][0-9]{2}:[0-9]{2})?[[:space:]]+\+?[0-9]+[a-zA-Z]+$ ]]; then
    echo "OFFSET"
    return 0
  fi

  # 3. Matcha HH:MM, HH.MM
  if [[ "$param" =~ ^([0-9]{1,2}:[0-9]{2}|[0-9]{1,2}\.[0-9]{2})$ ]]; then
    echo "TIME"
    return 0
  fi

  # 4. Exakt 4 siffror: tolkas som TIME (ex: 0930)
  if [[ "$param" =~ ^[0-9]{4}$ ]]; then
    echo "TIME"
    return 0
  fi

  # 5. Endast siffror, upp till 3: tolkas som OFFSET (ex: 30 => 30 min)
  if [[ "$param" =~ ^[0-9]{1,3}$ ]]; then
    echo "OFFSET"
    return 0
  fi

  # 6. Offset-format med enheter: +1h30m, 45min, 1t30min
  if [[ "$param" =~ ^\+?[0-9]+([htm]|h|hr|hour|tim|timme|timmar|m|min|minut|minuter|minutes)+$ ]]; then
    echo "OFFSET"
    return 0
  fi

  __log_error "ERROR: kan inte tolka tidsangivelsen \"$param\""
  return 1
}

function __is_time_or_offset__maybey {
  local param="$1"

  # 1. Endast ISO-datum utan tid
  if __is_valid_date "$param" > /dev/null; then
    echo "TIME"
    return 0
  fi
  # 1. Endast ISO-datum med tid
  #if [[ "$param" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}$ ]]; then
  #  echo "TIME"
  #  return 0
  #fi

  # 2. ISO-datum med tid OCH offset (ex: +30m, +1h30m)
  if [[ "$param" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}[[:space:]]+\+[0-9a-zA-Z]+$ ]]; then
    echo "OFFSET"
    return 0
  fi

  # 3. Matchar HH:MM, 09.30 etc
  if [[ "$param" =~ ^([0-9]{1,2}:[0-9]{2}|[0-9]{1,2}\.[0-9]{2})$ ]]; then
    echo "TIME"
    return 0
  fi

  # 4. Matchar exakt 4 siffror: 0930 = 09:30
  if [[ "$param" =~ ^[0-9]{4}$ ]]; then
    echo "TIME"
    return 0
  fi

  # 5. Matchar offset: t.ex. +30m, 90min, 1h30m
  if [[ "$param" =~ ^(\+)?([0-9]+(h|hr|hour|tim|timme|timmar|m|min|minuter|minutes))+$ ]]; then
    echo "OFFSET"
    return 0
  fi

  # 6. Enbart siffror: t.ex. "30" = 30 minuter
  if [[ "$param" =~ ^[0-9]{1,3}$ ]]; then
    echo "OFFSET"
    return 0
  fi

  __log_error "ERROR: kan inte tolka tidsangivelsen \"$param\""
  return 1
}

function __is_time_or_offset__xx() {
  local param="$1"

  # 1. Matchar ISO8601-tid (YYYY-MM-DDTHH:MM), ev. med offset efteråt
  if [[ "$param" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}([[:space:]]*\+[0-9]+[hm]*)?$ ]]; then
    echo "TIME"
    return 0
  # 2. Matchar explicita klockslag med kolon eller punkt (09:30, 9.30)
  elif [[ "$param" =~ ^([0-9]{1,2}:[0-9]{2}|[0-9]{1,2}\.[0-9]{2})$ ]]; then
    echo "TIME"
    return 0

  # 3. Exakt 4 siffror: tolkas som TIME (t.ex. 0130 ? 01:30)
  elif [[ "$param" =~ ^[0-9]{4}$ ]]; then
    echo "TIME"
    return 0

  # 4. siffror utan enhet: tolkas som OFFSET (t.ex. 120 => 120 min)
  elif [[ "$param" =~ ^[0-9]{1,3}$ ]]; then
    echo "OFFSET"
    return 0

  # 4. Offset med + eller med tidsenhet (t.ex. +1h30m, 2tim45min)
  elif [[ "$param" =~ ^(\+)?([0-9]+[hm]|[0-9]+(h|hr|hour|tim|timme|timmar|m|min|minuter|minutes))+$ ]]; then
    echo "OFFSET"
    return 0

  # 5. Annars: fel
  else
    __log_error "ERROR: kan inte tolka tidsangivelsen \"$param\""
    return 1
  fi
}

#@ Tolkar now, nu till YYY-MM-DDThh:mm
# Ska klara offsets
function __parse_now_timexxx() {
  local input="$1"

  case "${input,,}" in
    now | nu )
      local currentTime=$(date +"%Y-%m-%dT%H:%M")
      if __is_time_or_offset "$currentTime" | grep -q "OFFSET"; then
         echo "Yes it has offset"
        local timev=$(__add_offset_to_datetime "$input")
        echo "$timev"
      fi

  echo "HHH"

      date +"%Y-%m-%dT%H:%M"
      ;;
    *)
      echo "ERROR: Ogiltig inmatning för 'nu': $input" >&2
      return 1
      ;;
  esac
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


function __is_only_date_string_xxx() {
  local input="$1"

  # Trimma eventuell whitespace
  input=$(__trim "$input")

  # Format: YYYYMMDD eller YYMMDD eller MMDD
  if [[ "$input" =~ ^[0-9]{6,8}$ ]]; then
    return 99
    #return __is_valid_date
  fi
  # Format: MMDD
  if [[ "$input" =~ ^[0-9]{4}$ ]]; then
    return 0
  fi

  # Format YYYY-MM-DD eller YYYY/MM/DD
  if [[ "$input" =~ ^[0-9]{4}[-/][0-9]{2}[-/][0-9]{2}$ ]]; then
    return 0
  fi

  # Matchar YY-MM-DD eller YY/MM/DD
  if [[ "$input" =~ ^[0-9]{2}[-/][0-9]{2}[-/][0-9]{2}$ ]]; then
    return 0
  fi

  # Matchar MM-DD eller MM/DD
  if [[ "$input" =~ ^[0-9]{2}[-/][0-9]{2}$ ]]; then
    return 0
  fi


  return 1
}


function __is_date_string_xxx() {
  local input="$1"

  # Trimma och extrahera första "ordet" som potentiellt är ett datum
  local first_part="${input%% *}"
  first_part="${first_part%%T*}"  # ignorera eventuell T-tid

  # Ta bort bindestreck eller snedstreck för enklare matchning
  local clean="${first_part//[-\/]/}"

  # Matcha mot olika datumformat

  # Format: YYYYMMDD eller YYMMDD
  if [[ "$clean" =~ ^[0-9]{6,8}$ ]]; then
    return 0
  fi

  # Format: YYYY-MM-DD eller YYYY/MM/DD
  if [[ "$input" =~ ^[0-9]{4}[-/][0-9]{2}[-/][0-9]{2} ]]; then
    return 0
  fi

  # Format: YY-MM-DD eller YY/MM/DD
  if [[ "$input" =~ ^[0-9]{2}[-/][0-9]{2}[-/][0-9]{2} ]]; then
    return 0
  fi

  # Format: MM-DD eller MM/DD
  if [[ "$input" =~ ^[0-9]{2}[-/][0-9]{2} ]]; then
    return 0
  fi

  return 1
}

function __is_only_date_string_yyyy() {
  local input="$1"
  input=$(__trim "$input")

  # Försök normalisera och validera
  local date_part
  date_part=$(__normalize_date "$input") || return 1

  if date -d "$date_part" >/dev/null 2>&1; then
    return 0
  fi

  return 1
}
