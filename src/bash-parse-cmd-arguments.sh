#!/usr/bin/env bash

# ==============================
# Bash CLI Parser (sentinel required)
# ==============================

SENTINEL="__UNSET__"

if [ -t 1 ]; then
  C1=$(tput setaf 2)
  C2=$(tput setaf 4)
  CERR=$(tput setaf 1)
  CB=$(tput bold)
  CR=$(tput sgr0)
else
  C1=""; C2=""; CERR=""; CB=""; CR=""
fi



function example() {

# ================== EXEMPEL ==================
FLAGS=(
  "desc   | d  | s | 1 |    | Mötesbeskrivning (krävs)     | str"
  "repeat | r  | s | 0 | weekly | Hur ofta                 | str"
  "tags   | t  | m | 0 |    | Taggar (kan anges flera gånger) | str"
  "count  | c  | s | 0 | 1  | Antal upprepningar          | int"
  "dry_run|    | b | 0 |    | Torrkörning                 | bool"
  "note   | n  | s | 0 |    | Noteringsfil                | str"
  "help   | h  | h | 0 |    | Visa hjälp                  | "
)
POSITIONALS_SPEC=("inputfile:str:Indatafil:" "num:int:Antal rader:5")

parse_args FLAGS POSITIONALS_SPEC "$@"

# ===== Test/demo =====
echo "DESC: $DESC"
echo "REPEAT: $REPEAT"
echo "TAGS: $TAGS"
echo "TAGS_ARR: ${TAGS_ARR[*]}"
echo "DRY_RUN: $DRY_RUN"
echo "NOTE: $NOTE"
echo "COUNT: $COUNT"
echo "INPUTFILE: $INPUTFILE"
echo "NUM: $NUM"
echo "POSITIONALS: ${POSITIONAL[*]}"

}



function trim_args() {
  local var="$*"
  var="${var#"${var%%[![:space:]]*}"}"
  var="${var%"${var##*[![:space:]]}"}"
  var="${var//$'\r'/}"
  var="${var//$'\n'/}"
  echo -n "$var"
}

function check_valtype() {
  local val="$1" type="$2" regex="$3"
  case "$type" in
    int) [[ "$val" =~ ^-?[0-9]+$ ]] ;;
    float) [[ "$val" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] ;;
    bool) [[ "$val" =~ ^(0|1|true|false|yes|no)$ ]] ;;
    file) [[ -f "$val" ]] ;;
    dir) [[ -d "$val" ]] ;;
    regex) [[ "$val" =~ $regex ]] ;;
    str|"") true ;;
    *) false ;;
  esac
}

function print_help() {
  print_help_color "$@"
}

function print_help_color() {
  local prog="$1"
  local -n flag_defs=$2
  local -n pos_defs=$3

  {
    echo -e "${CB}Usage:${CR} $prog [options] ${C1}${pos_defs[*]//:*}${CR}\n"
    printf "%-18s %-7s %-10s %-8s %-12s %-10s %s\n" "Flag" "Short" "Type" "Req'd" "Default" "Valtype" "Description"
    echo "----------------------------------------------------------------------------------------------------------------------"
    for def in "${flag_defs[@]}"; do
      IFS='|' read -r flag short type required default desc valtype regex <<< "$def"
      flag=$(trim "$flag"); short=$(trim "$short"); type=$(trim "$type")
      required=$(trim "$required"); default=$(trim "$default"); desc=$(trim "$desc")
      valtype=$(trim "$valtype"); regex=$(trim "$regex")
      local flagstr="--$flag"
      local shortstr=${short:+-$short}
      [[ "$type" == "s" ]] && type="string"
      [[ "$type" == "b" ]] && type="bool"
      [[ "$type" == "m" ]] && type="multi"
      [[ "$type" == "h" ]] && type="help"
      local req_str
      if [[ "$required" == "1" ]]; then
        req_str="YES"
        desc="${desc} [REQUIRED]"
      else
        req_str="no"
      fi
      printf "%-18s %-7s %-10s %-8s %-12s %-10s %s\n" \
        "$flagstr" "$shortstr" "$type" "$req_str" "$default" "$valtype" "$desc"
    done

    if [[ "${#pos_defs[@]}" -gt 0 ]]; then
      echo -e "\n${CB}Positionella argument:${CR}"
      for pos in "${pos_defs[@]}"; do
        IFS=':' read -r pname ptype pdesc pdefault <<< "$pos"
        pname=$(trim "$pname"); ptype=$(trim "$ptype")
        pdesc=$(trim "$pdesc"); pdefault=$(trim "$pdefault")
        local required_label=""
        if [[ -z "$pdefault" ]]; then
          required_label="[REQUIRED]"
        fi
        printf "  %-12s %-8s %-12s %s\n" \
          "$pname" "$ptype" "$required_label" "$pdesc"
      done
    fi
    echo ""
  } | sed -e $'s/YES/\033[1;31mYES\033[0m/g' \
          -e $'s/\\[REQUIRED\\]/\033[1;31m[REQUIRED]\033[0m/g'
}


print_help_black-white() {
  local prog="$1"
  local -n flag_defs=$2
  local -n pos_defs=$3
  echo -e "${CB}Usage:${CR} $prog [options] ${C1}${pos_defs[*]//:*}${CR}\n"
  printf "%-18s %-7s %-10s %-8s %-12s %-10s %s\n" "Flag" "Short" "Type" "Req'd" "Default" "Valtype" "Description"
  echo "----------------------------------------------------------------------------------------------------------------------"
  for def in "${flag_defs[@]}"; do
    IFS='|' read -r flag short type required default desc valtype regex <<< "$def"
    flag=$(trim "$flag"); short=$(trim "$short"); type=$(trim "$type")
    required=$(trim "$required"); default=$(trim "$default"); desc=$(trim "$desc")
    valtype=$(trim "$valtype"); regex=$(trim "$regex")
    local flagstr="--$flag"
    local shortstr=${short:+-$short}
    [[ "$type" == "s" ]] && type="string"
    [[ "$type" == "b" ]] && type="bool"
    [[ "$type" == "m" ]] && type="multi"
    [[ "$type" == "h" ]] && type="help"
    local req_str
    if [[ "$required" == "1" ]]; then
      req_str="YES"
      desc="${desc} [REQUIRED]"
    else
      req_str="no"
    fi
    # Skriv först kolumnraden utan färg
    printf "%-18s %-7s %-10s %-8s %-12s %-10s %s\n" \
      "$flagstr" "$shortstr" "$type" "$req_str" "$default" "$valtype" "$desc"
  done
  if [[ "${#pos_defs[@]}" -gt 0 ]]; then
    echo -e "\n${CB}Positionella argument:${CR}"
    for pos in "${pos_defs[@]}"; do
      IFS=':' read -r pname ptype pdesc pdefault <<< "$pos"
      pname=$(trim "$pname"); ptype=$(trim "$ptype")
      pdesc=$(trim "$pdesc"); pdefault=$(trim "$pdefault")
      local required_label=""
      if [[ -z "$pdefault" ]]; then
        required_label="[REQUIRED]"
      fi
      printf "  %-12s %-8s %-12s %s\n" \
        "$pname" "$ptype" "$required_label" "$pdesc"
    done
  fi
  echo ""

  # Sedan färg-markera YES och [REQUIRED] i efterhand (tillval)
  # Det är fult men säkert:
  # sed 's/YES/\x1b[1;31mYES\x1b[0m/g; s/\[REQUIRED\]/\x1b[1;31m[REQUIRED]\x1b[0m/g'
}

function parse_args() {
  local -n flags=$1
  shift
  local -n positionals_spec=$1
  shift

  declare -A FLAG_TYPES FLAG_SHORTS FLAG_REQUIRED FLAG_DEFAULT FLAG_DESC FLAG_MULTI FLAG_VALTYPE FLAG_VALUES FLAG_REGEX FLAG_SET
  POSITIONAL=()
  declare -A POSITIONAL_TYPES POSITIONAL_DESC POSITIONAL_DEFAULT

  # Bygg flaggtabeller med trimning
  for def in "${flags[@]}"; do
    IFS='|' read -r flag short type required default desc valtype regex <<< "$def"
    flag=$(trim "$flag"); short=$(trim "$short"); type=$(trim "$type")
    required=$(trim "$required"); default=$(trim "$default"); desc=$(trim "$desc")
    valtype=$(trim "$valtype"); regex=$(trim "$regex")
    FLAG_TYPES["$flag"]="$type"
    [[ -n "$short" ]] && FLAG_SHORTS["$short"]="$flag"
    FLAG_REQUIRED["$flag"]="$required"
    FLAG_DEFAULT["$flag"]="$default"
    FLAG_DESC["$flag"]="$desc"
    FLAG_VALTYPE["$flag"]="$valtype"
    FLAG_REGEX["$flag"]="$regex"
    [[ "$type" == "m" ]] && FLAG_MULTI["$flag"]=1
  done

  # Positionella tabeller med trim
  for idx in "${!positionals_spec[@]}"; do
    IFS=':' read -r pname ptype pdesc pdefault <<< "${positionals_spec[$idx]}"
    pname=$(trim "$pname"); ptype=$(trim "$ptype")
    pdesc=$(trim "$pdesc"); pdefault=$(trim "$pdefault")
    POSITIONAL_TYPES["$pname"]="$ptype"
    POSITIONAL_DESC["$pname"]="$pdesc"
    POSITIONAL_DEFAULT["$pname"]="$pdefault"
  done

  # --- Argument-parsning med SET-markering ---
  while [[ $# -gt 0 ]]; do
    arg="$1"
    if [[ "$arg" =~ ^--([a-zA-Z0-9_-]+)=(.*)$ ]]; then
      key=$(trim "${BASH_REMATCH[1]//-/_}")
      val="${BASH_REMATCH[2]}"
      type="${FLAG_TYPES[$key]}"
      if [[ -z "$type" ]]; then echo -e "${CERR}Unknown option: --$key${CR}" >&2; exit 1; fi
      if [[ "$type" == "h" ]]; then print_help "$0" flags positionals_spec; exit 0
      elif [[ "$type" == "s" ]]; then FLAG_VALUES["$key"]="$val"; FLAG_SET["$key"]=1
      elif [[ "$type" == "m" ]]; then FLAG_VALUES["$key"]+="${FLAG_VALUES[$key]:+|}$val"; FLAG_SET["$key"]=1
      fi
      shift
    elif [[ "$arg" =~ ^--([a-zA-Z0-9_-]+)$ ]]; then
      key=$(trim "${BASH_REMATCH[1]//-/_}")
      type="${FLAG_TYPES[$key]}"
      if [[ -z "$type" ]]; then echo -e "${CERR}Unknown option: $arg${CR}" >&2; exit 1; fi
      if [[ "$type" == "h" ]]; then print_help "$0" flags positionals_spec; exit 0
      elif [[ "$type" == "s" ]]; then FLAG_VALUES["$key"]="$2"; FLAG_SET["$key"]=1; shift 2
      elif [[ "$type" == "m" ]]; then FLAG_VALUES["$key"]+="${FLAG_VALUES[$key]:+|}$2"; FLAG_SET["$key"]=1; shift 2
      elif [[ "$type" == "b" ]]; then FLAG_VALUES["$key"]=1; FLAG_SET["$key"]=1; shift
      fi
    elif [[ "$arg" =~ ^-([a-zA-Z0-9])$ ]]; then
      s=$(trim "${BASH_REMATCH[1]}")
      key="${FLAG_SHORTS[$s]}"
      key=$(trim "$key")
      type="${FLAG_TYPES[$key]}"
      if [[ -z "$key" ]]; then echo -e "${CERR}Unknown short option: $arg${CR}" >&2; exit 1; fi
      if [[ "$type" == "h" ]]; then print_help "$0" flags positionals_spec; exit 0
      elif [[ "$type" == "s" ]]; then FLAG_VALUES["$key"]="$2"; FLAG_SET["$key"]=1; shift 2
      elif [[ "$type" == "m" ]]; then FLAG_VALUES["$key"]+="${FLAG_VALUES[$key]:+|}$2"; FLAG_SET["$key"]=1; shift 2
      elif [[ "$type" == "b" ]]; then FLAG_VALUES["$key"]=1; FLAG_SET["$key"]=1; shift
      fi
    else
      POSITIONAL+=("$arg"); shift
    fi
  done

  # Sätt sentinel på alla required flaggor som ej angetts
  for def in "${flags[@]}"; do
    IFS='|' read -r flag short type required default desc valtype regex <<< "$def"
    flag=$(trim "$flag")
    required=$(trim "$required")
    default=$(trim "$default")
    if [[ -z "${FLAG_VALUES[$flag]}" ]]; then
      if [[ "$required" == "1" ]]; then
        FLAG_VALUES["$flag"]="$SENTINEL"
      elif [[ -n "$default" ]]; then
        FLAG_VALUES["$flag"]="$default"
      fi
    fi
  done

  # Validera required och typvalidering flaggor
  local errors=0
  for def in "${flags[@]}"; do
    IFS='|' read -r flag short type required default desc valtype regex <<< "$def"
    flag=$(trim "$flag"); valtype=$(trim "$valtype"); regex=$(trim "$regex")
    val="${FLAG_VALUES[$flag]}"
    val_trimmed=$(trim "$val")
    if [[ $(trim "$required") == "1" && $(trim "$val") == "$SENTINEL" ]]; then
        echo -e "${CERR}Missing required argument: --$flag${CR}" >&2; errors=1
    fi
    if [[ -n "$val_trimmed" && "$val" != "$SENTINEL" && -n "$valtype" ]]; then
      if ! check_valtype "$val_trimmed" "$valtype" "${regex:-}"; then
        echo -e "${CERR}Invalid value for --$flag: $val (should be $valtype)${CR}" >&2; errors=1
      fi
    fi
  done

  # Positionella: samma som tidigare
  for idx in "${!positionals_spec[@]}"; do
    IFS=':' read -r pname ptype pdesc pdefault <<< "${positionals_spec[$idx]}"
    pname=$(trim "$pname"); ptype=$(trim "$ptype"); pdefault=$(trim "$pdefault")
    if [[ -z "${POSITIONAL[$idx]}" ]]; then
      if [[ -n "${!pname}" ]]; then
        POSITIONAL[$idx]="${!pname}"
      elif [[ -n "$pdefault" ]]; then
        POSITIONAL[$idx]="$pdefault"
      fi
    fi
    local pval="${POSITIONAL[$idx]}"
    pval_trimmed=$(trim "$pval")
    if [[ -n "$pval_trimmed" && -n "$ptype" ]]; then
      if ! check_valtype "$pval_trimmed" "$ptype"; then
        echo -e "${CERR}Invalid value for positional $pname: $pval (should be $ptype)${CR}" >&2; errors=1
      fi
    fi
  done

  if [[ "${#POSITIONAL[@]}" -lt "${#positionals_spec[@]}" ]]; then
    echo -e "${CERR}Missing required positional argument(s): ${positionals_spec[*]}${CR}" >&2
    errors=1
  fi

  if [[ $errors -ne 0 ]]; then
    print_help "$0" flags positionals_spec
    exit 2
  fi

  # Exportera flaggor och multi-arrayer
  for flag in "${!FLAG_TYPES[@]}"; do
    if [[ "${FLAG_MULTI[$flag]}" == "1" && -n "${FLAG_VALUES[$flag]}" && "${FLAG_VALUES[$flag]}" != "$SENTINEL" ]]; then
      IFS='|' read -r -a arr <<< "${FLAG_VALUES[$flag]}"
      eval "${flag^^}_ARR=(\"\${arr[@]}\")"
      export "${flag^^}_ARR"
    else
      export "${flag^^}"="${FLAG_VALUES[$flag]}"
    fi
  done
  # Exportera positionella argument
  local idx=0
  for pname in "${!positionals_spec[@]}"; do
    IFS=':' read -r pname ptype pdesc pdefault <<< "${positionals_spec[$idx]}"
    pname=$(trim "$pname")
    local val="${POSITIONAL[$idx]}"
    export "${pname^^}"="$val"
    ((idx++))
  done
  export POSITIONAL
}
