#!/usr/bin/env bash
# ==============================
# Bash CLI Parser (robust + no-color-on-pipe)
# Features:
#  - Bool-hantering: --flag / --no-flag / --flag=false/0
#  - Kortflaggor: -abc, -n42, -n=42, -n 42
#  - "--" terminerar flaggparsning
#  - @argsfil: expandera argument från fil (kommentarer med #, tomma rader ignoreras)
#  - --version (finns alltid, oavsett schema)
#  - --completion[=bash|zsh]: skriver bash-kompatibel completion (zsh via bashcompinit)
#  - Schemakoll: varna om okända typkoder/fält
#  - Färg bara om TTY och NO_COLOR inte är satt
# ==============================

SENTINEL="__UNSET__"
CLI_VERSION="0.2.0"  # ändra vid release

# ---- Color handling ----
WANT_COLOR=0
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  WANT_COLOR=1
fi
if (( WANT_COLOR )); then
  C1=$(tput setaf 2)  # green
  C2=$(tput setaf 4)  # blue
  CERR=$(tput setaf 1) # red
  CB=$(tput bold)
  CR=$(tput sgr0)
else
  C1=""; C2=""; CERR=""; CB=""; CR=""
fi

# ---- Utilities ----
trim() {
  local var="$*"
  var="${var#"${var%%[![:space:]]*}"}"
  var="${var%"${var##*[![:space:]]}"}"
  var="${var//$'\r'/}"
  var="${var//$'\n'/}"
  printf "%s" "$var"
}

check_valtype() {
  local val="$1" type="$2" regex="$3"
  case "$type" in
    int)   [[ "$val" =~ ^-?[0-9]+$ ]] ;;
    float) [[ "$val" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] ;;
    bool)  [[ "$val" =~ ^(0|1|true|false|yes|no)$ ]] ;;
    file)  [[ -f "$val" ]] ;;
    dir)   [[ -d "$val" ]] ;;
    regex) [[ "$val" =~ $regex ]] ;;
    str|"") true ;;
    *) false ;;
  esac
}

_print_help_table() {
  local prog="$1"
  local -n flag_defs=$2
  local -n pos_defs=$3

  echo -e "${CB}Usage:${CR} $prog [options] ${C1}${pos_defs[*]//:*}${CR}\n"
  printf "%-18s %-7s %-10s %-8s %-12s %-10s %-16s %s\n" \
    "Flag" "Short" "Type" "Req'd" "Default" "Valtype" "Regex" "Description"
  echo "-------------------------------------------------------------------------------------------------------------------------------"
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
    local req_str="no"
    if [[ "$required" == "1" ]]; then
      req_str=$([[ -n "$CERR$CB$CR" ]] && printf "${CB}${CERR}YES${CR}" || printf "YES")
      desc="${desc} $([[ -n "$CERR$CB$CR" ]] && printf "${CB}${CERR}[REQUIRED]${CR}" || printf "[REQUIRED]")"
    fi
    printf "%-18s %-7s %-10s %-8s %-12s %-10s %-16s %s\n" \
      "$flagstr" "$shortstr" "$type" "$req_str" "$default" "${valtype:-str}" "${regex:-}" "$desc"
  done

  if [[ "${#pos_defs[@]}" -gt 0 ]]; then
    echo -e "\n${CB}Positionella argument:${CR}"
    printf "  %-12s %-8s %-12s %s\n" "Name" "Type" "Req'd" "Description"
    for pos in "${pos_defs[@]}"; do
      IFS=':' read -r pname ptype pdesc pdefault <<< "$pos"
      pname=$(trim "$pname"); ptype=$(trim "$ptype")
      pdesc=$(trim "$pdesc"); pdefault=$(trim "$pdefault")
      local req_label=""
      if [[ -z "$pdefault" ]]; then
        req_label=$([[ -n "$CERR$CB$CR" ]] && printf "${CB}${CERR}[REQUIRED]${CR}" || printf "[REQUIRED]")
      fi
      printf "  %-12s %-8s %-12s %s\n" "$pname" "$ptype" "$req_label" "$pdesc"
    done
  fi
  echo ""
}

print_help() {
  local prog="$1"; local -n flag_defs=$2; local -n pos_defs=$3
  _print_help_table "$prog" flag_defs pos_defs
}

# Expand @argsfile tokens innan parsning
_expand_argsfiles() {
  # läs alla in-argument och expandera @file till ordlista
  local out=() tok file line words
  for tok in "$@"; do
    if [[ "$tok" == @* && -f "${tok#@}" ]]; then
      file="${tok#@}"
      while IFS= read -r line || [[ -n "$line" ]]; do
        # hoppa över kommentarer och tomma rader
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        # använd Bash orddelning (respekterar citat)
        read -r -a words <<< "$line"
        for w in "${words[@]}"; do out+=("$w"); done
      done < "$file"
    else
      out+=("$tok")
    fi
  done
  printf '%s\n' "${out[@]}"
}

# Generera bash-kompatibel completion (fungerar i zsh via bashcompinit)
_emit_completion() {
  local prog="$1"; shift
  local -n flag_defs=$1
  local longs=() shorts=()
  for def in "${flag_defs[@]}"; do
    IFS='|' read -r flag short type _ _ _ _ _ <<< "$def"
    flag=$(trim "$flag"); short=$(trim "$short")
    [[ -n "$flag" ]] && longs+=("--$flag")
    [[ -n "$short" ]] && shorts+=("-$short")
  done
  # lägg till inbyggda
  longs+=("--version" "--completion")
  cat <<'BASHCOMP'
# shellcheck disable=SC2148
__CLI_WORDS=()
_cli_array_join() { local IFS=" "; printf "%s" "$*"; }

_cli_complete() {
  local cur prev words cword
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  # ordlista
  local __longs __shorts
BASHCOMP
  printf '__longs=(%s)
' "$(printf ' %q' "${longs[@]}")"
  printf '__shorts=(%s)
' "$(printf ' %q' "${shorts[@]}")"
  cat <<'BASHCOMP'
  if [[ "$cur" == --* ]]; then
    COMPREPLY=( $(compgen -W "$(__cli_array_join "${__longs[@]}")" -- "$cur") )
    return 0
  elif [[ "$cur" == -* ]]; then
    COMPREPLY=( $(compgen -W "$(__cli_array_join "${__shorts[@]}")" -- "$cur") )
    return 0
  fi
  # fallback: fil/dir
  COMPREPLY=( $(compgen -f -- "$cur") )
  return 0
}
complete -o filenames -F _cli_complete "__PROG__"
BASHCOMP
  # ersätt programnamn i sista raden
}

parse_args() {
  local -n flags=$1; shift
  local -n positionals_spec=$1; shift

  # schema-sanity
  local _warn=0
  for def in "${flags[@]}"; do
    IFS='|' read -r flag short type required default desc valtype regex <<< "$def"
    [[ -z "$flag" ]] && { echo "${CERR}WARN:${CR} tomt flaggnamn i schema" >&2; _warn=1; }
    [[ "$type" =~ ^(s|m|b|h)$ ]] || { echo "${CERR}WARN:${CR} okänd typ '$type' för --$flag" >&2; _warn=1; }
  done
  (( _warn )) && :

  # expandera @argsfiler
  if (($#)); then
    mapfile -t _expanded < <(_expand_argsfiles "$@")
    set -- "${_expanded[@]}"
  fi

  # Särskild hantering: --version / --completion tidigt
  for a in "$@"; do
    case "$a" in
      --version)
        echo "${0##*/} ${CLI_VERSION}"; return 129 ;;
      --completion|--completion=*)
        local shell="bash"
        [[ "$a" == --completion=* ]] && shell="${a#--completion=}"
        local prog="${0##*/}"
        local completion
        completion=$(_emit_completion "$prog" flags)
        completion=${completion/__PROG__/$prog}
        echo "$completion"
        return 130 ;;
    esac
  done

  # maps
  declare -A FLAG_TYPES FLAG_SHORTS FLAG_REQUIRED FLAG_DEFAULT FLAG_DESC FLAG_MULTI FLAG_VALTYPE FLAG_VALUES FLAG_REGEX FLAG_SET
  POSITIONAL=()
  declare -A POSITIONAL_TYPES POSITIONAL_DESC POSITIONAL_DEFAULT

  # normalize and load flag schema
  for def in "${flags[@]}"; do
    IFS='|' read -r flag short type required default desc valtype regex <<< "$def"
    flag=$(trim "$flag")
    local key_norm="${flag//-/_}"
    short=$(trim "$short"); type=$(trim "$type")
    required=$(trim "$required"); default=$(trim "$default"); desc=$(trim "$desc")
    valtype=$(trim "$valtype"); regex=$(trim "$regex")

    FLAG_TYPES["$key_norm"]="$type"
    [[ -n "$short" ]] && FLAG_SHORTS["$short"]="$key_norm"
    FLAG_REQUIRED["$key_norm"]="$required"
    FLAG_DEFAULT["$key_norm"]="$default"
    FLAG_DESC["$key_norm"]="$desc"
    FLAG_VALTYPE["$key_norm"]="$valtype"
    FLAG_REGEX["$key_norm"]="$regex"
    [[ "$type" == "m" ]] && FLAG_MULTI["$key_norm"]=1
  done

  # positional schema
  for idx in "${!positionals_spec[@]}"; do
    IFS=':' read -r pname ptype pdesc pdefault <<< "${positionals_spec[$idx]}"
    pname=$(trim "$pname"); ptype=$(trim "$ptype")
    pdesc=$(trim "$pdesc"); pdefault=$(trim "$pdefault")
    POSITIONAL_TYPES["$pname"]="$ptype"
    POSITIONAL_DESC["$pname"]="$pdesc"
    POSITIONAL_DEFAULT["$pname"]="$pdefault"
  done

  _set_flag_val() {
    local key="$1" type="$2" val="$3"
    case "$type" in
      h) print_help "$0" flags positionals_spec; exit 0 ;;
      b)
        if [[ -z "$val" ]]; then
          FLAG_VALUES["$key"]=1
        else
          local v; v="$(trim "$val")"; v="${v,,}"
          case "$v" in
            1|true|yes) FLAG_VALUES["$key"]=1 ;;
            0|false|no) FLAG_VALUES["$key"]=0 ;;
            *) echo -e "${CERR}Invalid boolean for --${key//_/-}: $val${CR}" >&2; exit 1 ;;
          esac
        fi
        FLAG_SET["$key"]=1 ;;
      m)
        FLAG_VALUES["$key"]+="${FLAG_VALUES[$key]+$'\x00'}$val"
        FLAG_SET["$key"]=1 ;;
      s)
        FLAG_VALUES["$key"]="$val"
        FLAG_SET["$key"]=1 ;;
      *) echo -e "${CERR}Unknown type for --${key//_/-}${CR}" >&2; exit 1 ;;
    esac
  }

  local arg end_of_opts=0
  while [[ $# -gt 0 ]]; do
    arg="$1"; shift
    if (( end_of_opts )); then POSITIONAL+=("$arg"); continue; fi

    case "$arg" in
      --) end_of_opts=1 ;;
      --no-*)
        local raw="${arg#--no-}"; local key="${raw//-/_}"; local type="${FLAG_TYPES[$key]}"
        [[ -z "$type" ]] && { echo -e "${CERR}Unknown option: --no-${raw}${CR}" >&2; exit 1; }
        _set_flag_val "$key" "$type" "false" ;;
      --*=*)
        local raw="${arg#--}"; local lhs="${raw%%=*}"; local rhs="${raw#*=}"
        local key="${lhs//-/_}"; local type="${FLAG_TYPES[$key]}"
        [[ -z "$type" ]] && { echo -e "${CERR}Unknown option: --${lhs}${CR}" >&2; exit 1; }
        _set_flag_val "$key" "$type" "$rhs" ;;
      --*)
        local raw="${arg#--}"; local key="${raw//-/_}"; local type="${FLAG_TYPES[$key]}"
        [[ -z "$type" ]] && { echo -e "${CERR}Unknown option: --${raw}${CR}" >&2; exit 1; }
        case "$type" in
          s|m)
            [[ $# -eq 0 ]] && { echo -e "${CERR}Missing value for --${raw}${CR}" >&2; exit 1; }
            _set_flag_val "$key" "$type" "$1"; shift ;;
          b|h) _set_flag_val "$key" "$type" "" ;;
        esac ;;
      -[!-]?*)
        local cluster="${arg#-}"; local i
        for (( i=0; i<${#cluster}; i++ )); do
          local ch="${cluster:i:1}"; local key="${FLAG_SHORTS[$ch]}"
          [[ -z "$key" ]] && { echo -e "${CERR}Unknown short option: -$ch${CR}" >&2; exit 1; }
          local type="${FLAG_TYPES[$key]}"
          if (( i < ${#cluster}-1 )) && [[ "$type" == "s" || "$type" == "m" ]]; then
            local rest="${cluster:i+1}"; rest="${rest#=}"
            _set_flag_val "$key" "$type" "$rest"; break
          else
            _set_flag_val "$key" "$type" ""
          fi
        done ;;
      -?=*)
        local ch="${arg:1:1}"; local key="${FLAG_SHORTS[$ch]}"; local type="${FLAG_TYPES[$key]}"
        [[ -z "$key" ]] && { echo -e "${CERR}Unknown short option: -$ch${CR}" >&2; exit 1; }
        _set_flag_val "$key" "$type" "${arg#?-?=}" ;;
      -?)
        local ch="${arg:1:1}"; local key="${FLAG_SHORTS[$ch]}"; local type="${FLAG_TYPES[$key]}"
        [[ -z "$key" ]] && { echo -e "${CERR}Unknown short option: $arg${CR}" >&2; exit 1; }
        if [[ "$type" == "s" || "$type" == "m" ]]; then
          [[ $# -eq 0 ]] && { echo -e "${CERR}Missing value for $arg${CR}" >&2; exit 1; }
          _set_flag_val "$key" "$type" "$1"; shift
        else
          _set_flag_val "$key" "$type" ""
        fi ;;
      *) POSITIONAL+=("$arg") ;;
    esac
  done

  # defaults / required
  for def in "${flags[@]}"; do
    IFS='|' read -r flag short type required default desc valtype regex <<< "$def"
    flag=$(trim "$flag"); local key="${flag//-/_}"
    required=$(trim "$required"); default=$(trim "$default")
    if [[ -z "${FLAG_VALUES[$key]+x}" ]]; then
      if [[ "$required" == "1" ]]; then
        FLAG_VALUES["$key"]="$SENTINEL"
      elif [[ -n "$default" ]]; then
        FLAG_VALUES["$key"]="$default"
      fi
    fi
  done

  # validation
  local errors=0
  for def in "${flags[@]}"; do
    IFS='|' read -r flag short type required default desc valtype regex <<< "$def"
    flag=$(trim "$flag"); valtype=$(trim "$valtype"); regex=$(trim "$regex")
    local key="${flag//-/_}"; local val="${FLAG_VALUES[$key]}"
    local vtrim; vtrim="$(trim "$val")"
    if [[ "$(trim "$required")" == "1" && "$vtrim" == "$SENTINEL" ]]; then
      echo -e "${CERR}Missing required argument: --${flag}${CR}" >&2; errors=1
    fi
    if [[ -n "$vtrim" && "$vtrim" != "$SENTINEL" && -n "$valtype" ]]; then
      if ! check_valtype "$vtrim" "$valtype" "${regex:-}"; then
        echo -e "${CERR}Invalid value for --$flag: $val (should be $valtype)${CR}" >&2; errors=1
      fi
    fi
  done

  # positionals
  for idx in "${!positionals_spec[@]}"; do
    IFS=':' read -r pname ptype pdesc pdefault <<< "${positionals_spec[$idx]}"
    pname=$(trim "$pname"); ptype=$(trim "$ptype"); pdefault=$(trim "$pdefault")
    if [[ -z "${POSITIONAL[$idx]+x}" ]]; then
      if [[ -n "${!pname}" ]]; then
        POSITIONAL[$idx]="${!pname}"
      elif [[ -n "$pdefault" ]]; then
        POSITIONAL[$idx]="$pdefault"
      fi
    fi
    local pval="${POSITIONAL[$idx]}"
    local ptrim; ptrim="$(trim "$pval")"
    if [[ -z "$ptrim" && -z "$pdefault" ]]; then
      echo -e "${CERR}Missing required positional: ${pname}${CR}" >&2; errors=1
    elif [[ -n "$ptrim" && -n "$ptype" ]]; then
      if ! check_valtype "$ptrim" "$ptype"; then
        echo -e "${CERR}Invalid value for positional $pname: $pval (should be $ptype)${CR}" >&2; errors=1
      fi
    fi
  done

  if (( errors )); then
    print_help "$0" flags positionals_spec
    exit 2
  fi

  # export flags -> UPPERCASE vars; multi -> _ARR
  for def in "${flags[@]}"; do
    IFS='|' read -r flag _ type _ _ _ _ _ <<< "$def"
    local key="${flag//-/_}"; local up="${key^^}"
    if [[ "${FLAG_MULTI[$key]}" == "1" && -n "${FLAG_VALUES[$key]}" && "${FLAG_VALUES[$key]}" != "$SENTINEL" ]]; then
      IFS=$'\x00' read -r -d '' -a arr < <(printf '%s\0' "${FLAG_VALUES[$key]}")
      eval "${up}_ARR=(\"\${arr[@]}\")"
      export "${up}"="${FLAG_VALUES[$key]//$'\x00'/,}"
    else
      export "${up}"="${FLAG_VALUES[$key]}"
    fi
  done

  # export positionals som NAMED uppercase vars
  local i=0
  for pos in "${positionals_spec[@]}"; do
    IFS=':' read -r pname _ _ _ <<< "$pos"
    local up="${pname^^}"
    export "${up}"="${POSITIONAL[$i]}"
    ((i++))
  done
}

# ---- Example (kan tas bort i produktion) ----
example() {
  FLAGS=(
    "desc   | d  | s | 1 |        | Mötesbeskrivning (krävs) | str"
    "repeat | r  | s | 0 | weekly | Hur ofta                 | str"
    "tags   | t  | m | 0 |        | Taggar (multipla)        | str"
    "count  | c  | s | 0 | 1      | Antal upprepningar       | int"
    "dry-run|    | b | 0 |        | Torrkörning              | bool"
    "note   | n  | s | 0 |        | Noteringsfil             | str"
    "help   | h  | h | 0 |        | Visa hjälp               | "
  )
  POSITIONALS_SPEC=("inputfile:str:Indatafil:" "num:int:Antal rader:5")
  parse_args FLAGS POSITIONALS_SPEC "$@"

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
