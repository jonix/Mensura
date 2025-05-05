#!/usr/bin/env bash

#  Förhindra direkt exekvering
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "❌ Denna fil är en modul och ska inte köras direkt."
  exit 1
fi

# Se till att denna fil laddas in en och endast en gång
#source "$(dirname "${BASH_SOURCE[0]}")/bash-guard.sh" || return
#__bash_module_guard || return
#echo "SOURCING FILE: ${BASH_SOURCE[0]}"

### Includes ###
source "$(dirname "${BASH_SOURCE[0]}")/tui-logging.sh"


# Statistik för antal tester
total=0
passed=0
failed=0


#@ Kör ett test givet från testcase katalogen, *.tests filer
function __run_test() {
  echo -e "\n🧪 Kör testfall från: $file"

  total=0
  passed=0
  failed=0

  # Parsa *.tests fil med format
  # #@ source: ../task-private.sh
  # Laddar in modulen som krävs för Unit testandet
  __load_module_to_test "$file"

  # Parsa *.tests fil med format
  # __time_or_offset|930|OFFSET
  while IFS='|' read -r func input expected; do
    # Hoppa över tomma rader eller rader som börjar med #
    [[ -z "$func" || "$func" == \#* ]] && continue
    run_test_case "$func" "$input" "$expected"
  done < "$file"

  # TODO: Kom ihåg att göra en unload module

  echo -e "\n📊 Totalt: $total | ${GREEN}✔︎ $passed${RESET} | ${RED}✘ $failed${RESET}"
  [[ $failed -eq 0 ]] && return 0 || return 1

}


# Alternativ metod som garanterar att alla modulder blir inladdade
# För att kunna köra alla tester
# OBS: Om inte varje fil har en Bash Include guard, så kommre det bli oändlig rekursion
# Rekommendar inte att använda denna function, istället __load_module_to_test
function __load_all_modules() {
 for file in task-*.sh; do
   [[ "$file" == *test* ]] && continue
   if [[ -f "$file" ]]; then
     echo "Läser in testdata filen $file"
     source "$file"
   fi
 done
}


# Varje *.tests data fil som definiera testcases
# ska även ha som första rad #@ source: ../filnamn.sh
# Som är relaterad till de tester som ska köras
function __load_module_to_test() {
  local testcase_file="$1" # Any Unit Test definition *.tests file,
  if [[ ! -f "$testcase_file" ]]; then
    __log_error "Kan inte ladda in testcase filen $testcase_file"
    return 1
  fi
  first_line=$(head -n 1 "$testcase_file")
  if [[ -z $first_line ]] ; then
    __log_error "Första raden i $testcase_file kräver definition av filen som har test-funktionerna"
    return 1
  fi

  if [[ "$first_line" =~ ^#@\ source:\ (.*) ]]; then
    module_file="${BASH_REMATCH[1]}"
    if [[ -f "$module_file" ]]; then
      __log_debug "Laddar task-modul $module_file från filen $testcase_file"
      source "$module_file"
    else
      __log_error "❌ Utifrån filen $testcase_file så kunde inte angiven modul hittas: $module_file"
      return 1
    fi
  fi
  return 0
}


__strip_ansi() {
  sed -E 's/\x1B\[[0-9;]*[mK]//g'
}

__assert_output_contains() {
  local output="$1"
  local needle="$2"
  local context="$3"

  ((total++))
  if echo "$output" | __strip_ansi | grep -q "$needle"; then
    ((passed++))
    echo -e "${GREEN}✔︎${RESET} $context innehåller ordet \"$needle\" som förväntad"
  else
    ((failed++))
    echo -e "${RED}✘${RESET} $context"
    echo -e "   Förväntade innehålla: $needle"
    echo -e "   Fick: $(echo \"$output\" | __strip_ansi)"
  fi
}

__assert_output_equals() {
  local output="$1"
  local expected="$2"
  local context="$3"

  ((total++))
  local clean=$(echo "$output" | __strip_ansi)
  if [[ "$clean" == "$expected" ]]; then
    ((passed++))
    echo -e "${GREEN}✔︎${RESET} $context → \"$clean\""
  else
    ((failed++))
    echo -e "${RED}✘${RESET} $context"
    echo -e "   Förväntat: \"$expected\""
    echo -e "   Fick:      \"$clean\""
  fi
}

function run_test_case__deprecated() {
  local func="$1"
  local input="$2"
  local expected="$3"

  local result
  result=$($func $input 2>&1)
  rc=$?
  if [[ $rc -gt 1 ]]; then
     echo "ERROR #$rc Något gick fel vid anrop till $func med input: $input"
     return 1
  fi

  if [[ "$expected" == "ERROR" ]]; then
    __assert_output_contains "$result" "ERROR" "$func \"$input\""
  else
    __assert_output_equals "$result" "$expected" "$func \"$input\""
  fi
}

function run_test_case__xxx() {
  local func="$1"
  local input="$2"
  local expected="$3"

  local result rc
  result=$($func $input 2>&1)
  rc=$?

  # Om expected är exakt ett heltal (0, 1, 42...), tolka det som returvärde
  if [[ "$expected" =~ ^[0-9]+$ ]]; then
    ((total++))
    if [[ "$rc" -eq "$expected" ]]; then
      ((passed++))
      echo -e "${GREEN}✔︎${RESET} $func \"$input\" returnerade $rc som förväntat"
    else
      ((failed++))
      echo -e "${RED}✘${RESET} $func \"$input\""
      echo -e "   Förväntad returnkod: $expected"
      echo -e "   Fick:                $rc"
    fi
    return
  fi

  # Om vi väntar oss ett felmeddelande
  if [[ "$expected" == "ERROR" ]]; then
    __assert_output_contains "$result" "ERROR" "$func \"$input\""
  else
    __assert_output_equals "$result" "$expected" "$func \"$input\""
  fi
}


run_test_case() {
  local func="$1"
  local raw_input="$2"
  local raw_expected="$3"

  if ! __is_safe_expression "$raw_input"; then
    __log_error "⚠️  Farligt uttryck i expected: $raw_expected"
    return 1
  fi


  if ! __is_safe_expression "$raw_expected"; then
    __log_error "⚠️  Farligt uttryck i expected: $raw_expected"
    return 1
  fi

  # 🧠 Expandera variabler i input och expected
  local input expected
  input=$(eval "echo \"$raw_input\"")
  expected=$(eval "echo \"$raw_expected\"")

  # 🧪 Dela upp input till argument-array
  IFS=' ' read -r -a args <<< "$input"

  local result rc
  result=$("$func" "${args[@]}" 2>&1)
  rc=$?

  # 📌 Om expected är ett tal, jämför return-kod
  if [[ "$expected" =~ ^[0-9]+$ ]]; then
    ((total++))
    if [[ "$rc" -eq "$expected" ]]; then
      ((passed++))
      echo -e "${GREEN}✔︎${RESET} $func \"$input\" returnerade $rc som förväntat"
    else
      ((failed++))
      echo -e "${RED}✘${RESET} $func \"$input\""
      echo -e "   Förväntad returnkod: $expected"
      echo -e "   Fick:                $rc"
    fi
    return
  fi

  # 🔍 Förväntad ERROR i utskrift
  if [[ "$expected" == "ERROR" ]]; then
    __assert_output_contains "$result" "ERROR" "$func \"$input\""
  else
    __assert_output_equals "$result" "$expected" "$func \"$input\""
  fi
}

__is_safe_expression() {
  local expr="$1"
  local allowed_commands=("date" "echo" "basename" "dirname")

  # Hitta alla $(...) uttryck
  local matches
  matches=$(echo "$expr" | grep -oP '\$\((.*?)\)' | sed -E 's/^\$\((.*?)\)$/\1/')

  # Om inga kommandon hittades, godkänn
  [[ -z "$matches" ]] && return 0

  # Kontrollera varje kommando i varje $(...)
  while IFS= read -r command; do
    local cmd_name
    cmd_name=$(echo "$command" | awk '{print $1}')
    local allowed=0
    for allowed_cmd in "${allowed_commands[@]}"; do
      if [[ "$cmd_name" == "$allowed_cmd" ]]; then
        allowed=1
        break
      fi
    done
    if [[ "$allowed" -eq 0 ]]; then
      echo "⛔ Otillåtet kommando i eval: '$cmd_name'" >&2
      return 1
    fi
  done <<< "$matches"

  return 0
}



function __is_safe_expression_xxx() {
  local expr="$1"

  # Tillåt endast följande "säkra" kommandon i $()
  local allowed_commands=("date" "echo" "basename" "dirname")

  # Extrahera alla kommandon från $(...)
  local matches
  matches=$(echo "$expr" | grep -oP '\$\((.*?)\)' | sed 's/[$()]//g')

  # Om inga kommandon, det är säkert
  [[ -z "$matches" ]] && return 0

  for cmd in $matches; do
    local name=$(echo "$cmd" | awk '{print $1}')
    local allowed=0
    for allowed_cmd in "${allowed_commands[@]}"; do
      if [[ "$name" == "$allowed_cmd" ]]; then
        allowed=1
        break
      fi
    done
    if [[ "$allowed" -eq 0 ]]; then
      echo "⛔ Otillåtet kommando i eval: '$name'"
      return 1
    fi
  done

  return 0
}

function find_untested_files() {
  echo "Söker efter .sh-filer i src/ utan motsvarande test i testcases/ ..."

  local src_dir="."
  local test_dir="$src_dir/testcases"

  local all_sh_files
  mapfile -t all_sh_files < <(find "$src_dir" -maxdepth 1 -name "*.sh" -printf "%f\n")

  local tested_files=()
  while read -r line; do
    if [[ "$line" =~ ^#@\ source:\ (.*) ]]; then
      tested_files+=("$(basename "${BASH_REMATCH[1]}")")
    fi
  done < <(grep -h '^#@ source:' "$test_dir"/*.test 2>/dev/null)

  for file in "${all_sh_files[@]}"; do
    if ! printf "%s\n" "${tested_files[@]}" | grep -qx "$file"; then
      echo "Ingen testfil för: $file"
    fi
  done
}

find_untested_functions-xxx() {
  echo "?? Letar efter funktioner utan tester..."

  local src_dir="."
  local test_dir="$src_dir/testcases"

  local all_funcs=()
  while read -r line; do
    if [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9_-]+)[[:space:]]*\(\)[[:space:]]*\{?$ ]]; then
      all_funcs+=("${BASH_REMATCH[1]}")
    fi
  done < <(grep -hE '^\s*[a-zA-Z0-9_-]+\s*\(\)' "$src_dir"/*.sh)

  local tested_funcs=()
  while read -r func; do
    tested_funcs+=("$func")
  done < <(awk -F'|' 'NF>=1 && $1 !~ /^#/ { gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1 }' "$test_dir"/*.test 2>/dev/null)

  for func in "${all_funcs[@]}"; do
    if ! printf "%s\n" "${tested_funcs[@]}" | grep -qx "$func"; then
      echo "??  Funktionen saknar test: $func"
    fi
  done
}


find-untested-functions-xxxxx() {
  echo "Letar efter funktioner utan tester (med stöd för # @untestable)..."

  local src_dir="."
  local test_dir="$sr_dir/testcases"

  declare -A all_funcs
  declare -a tested_funcs

  # Steg 1: Samla alla funktioner i varje .sh-fil (exkludera @untestable)
  for file in "$src_dir"/*.sh; do
    local previous_line=""
    while IFS= read -r line; do
      if [[ "$line" =~ ^[[:space:]]*#.*@untestable ]]; then
        previous_line="$line"
        continue
      fi

      if [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9_-]+)[[:space:]]*\(\)[[:space:]]*\{? ]]; then
        local fname="${BASH_REMATCH[1]}"
        if [[ "$previous_line" =~ @untestable ]]; then
          previous_line=""
          continue
        fi
        all_funcs["$fname"]="$file"
      fi

      previous_line="$line"
    done < "$file"
  done

  # Steg 2: Samla alla testade funktioner
  while IFS= read -r func; do
    tested_funcs+=("$func")
  done < <(awk -F'|' 'NF>=1 && $1 !~ /^#/ { gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1 }' "$test_dir"/*.test 2>/dev/null)

  # Steg 3: Jämför och rapportera otestade funktioner
  for func in "${!all_funcs[@]}"; do
    if ! printf "%s\n" "${tested_funcs[@]}" | grep -qx "$func"; then
      echo "??  Otestad funktion: $func (fil: ${all_funcs[$func]})"
    fi
  done
}

find-untested-functionsxx() {
  echo "🌲 Letar efter otestade funktioner i Mensura..."

  local src_dir="."
  local test_dir="$test_dir/testcases"

  declare -A all_funcs
  declare -a tested_funcs
  declare -A untested_by_file

  # 1. Samla alla funktioner i varje .sh-fil (förutom @untestable)
  for file in "$src_dir"/*.sh; do
    local previous_line=""
    while IFS= read -r line; do
      if [[ "$line" =~ ^[[:space:]]*#.*@untestable ]]; then
        previous_line="$line"
        continue
      fi

      if [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9_-]+)[[:space:]]*\(\)[[:space:]]*\{? ]]; then
        local fname="${BASH_REMATCH[1]}"
        if [[ "$previous_line" =~ @untestable ]]; then
          previous_line=""
          continue
        fi
        all_funcs["$file|$fname"]=1
      fi
      previous_line="$line"
    done < "$file"
  done

  # 2. Samla alla testade funktioner från alla testfiler
  while IFS= read -r func; do
    tested_funcs+=("$func")
  done < <(awk -F'|' 'NF>=1 && $1 !~ /^#/ { gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1 }' "$test_dir"/*.test 2>/dev/null)

  # 3. Samla otestade funktioner per fil
  for key in "${!all_funcs[@]}"; do
    local file="${key%%|*}"
    local fname="${key##*|}"

    if ! printf "%s\n" "${tested_funcs[@]}" | grep -qx "$fname"; then
      untested_by_file["$file"]+="$fname "
    fi
  done

  # 4. Visa som träd
  for file in "${!untested_by_file[@]}"; do
    echo "📄 ${file}"
    local funcs=(${untested_by_file[$file]})
    local last_index=$(( ${#funcs[@]} - 1 ))
    for i in "${!funcs[@]}"; do
      if [[ $i -eq $last_index ]]; then
        echo "   └── ${funcs[$i]}"
      else
        echo "   ├── ${funcs[$i]}"
      fi
    done
  done
}


# Kollar igenom alla *.sh filer och avgör om det fattas ett UnitTest till funktioner i testcases katalogen
# Skriver ut resultat som ett träd, default mässigt
#
# Opttions: Kan skriva ut ett träd, json fil eller kort text-form
# Options: Kan hålla sig til att bara kolla en namniven fil
#
# T ex
#  source unittest-utilities ; find_untested_functions --json parse-datetime.sh
#  OBS: formatet MÅSTE vara parameter 1
find_untested_functions() {
  # Kan styra vilket format som skrivs ut, --tree, --short eller --json
  local format="tree"

  local src_dir="."
  local test_dir="$src_dir/testcases"

  declare -A all_funcs
  declare -a tested_funcs
  declare -A untested_by_file

  local total=0
  local testade=0
  local otestade=0

  local files_to_check=()

  if [[ "$1" == "--short" ]]; then
    format="short"
    shift
  elif [[ "$1" == "--json" ]]; then
    format="json"
    shift
  fi

  if [[ -n "$1" ]]; then
    if [[ -f "$1" ]]; then
      files_to_check+=("$1")
    elif [[ -f "$src_dir/$1" ]]; then
      files_to_check+=("$src_dir/$1")
    else
      echo "ERROR: Filen kunde inte hittas: $1"
      return 1
    fi
  else
    mapfile -t files_to_check < <(find "$src_dir" -maxdepth 1 -type f -name "*.sh")
  fi

  if [[ "$format" == "tree" ]] ; then
    echo "🔎 Söker efter otestade funktioner i Mensura..."
  elif [[ "$format" == "short" ]] ; then
    echo "Söker efter otestade funktioner i Mensura..."
  elif [[ "$format" == "json" ]] ; then
    # Skriv ingen header i json formatet
    echo -n ""
  fi

  # 1. Hitta alla funktioner i angivna filer (förutom @untestable)
  for file in "${files_to_check[@]}"; do
    local previous_line=""
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" =~ ^[[:space:]]*#.*@untestable ]]; then
        previous_line="$line"
        continue
      fi
      if [[ "$line" =~ ^[[:space:]]*(function[[:space:]]+)?([a-zA-Z0-9_-]+)[[:space:]]*\(\)[[:space:]]*\{? ]]; then
        local fname="${BASH_REMATCH[2]}"
        if [[ "$previous_line" =~ @untestable ]]; then
          previous_line=""
          continue
        fi
        all_funcs["$file|$fname"]=1
        ((total++))
      fi
      previous_line="$line"
    done < "$file"
  done

  # 2. Samla alla testade funktioner från testcases/*.test
  while IFS= read -r line; do
    [[ "$line" =~ ^# ]] && continue
    func=$(echo "$line" | awk -F'|' '{ gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1 }')
    [[ -n "$func" ]] && tested_funcs+=("$func")
  done < <(cat "$test_dir"/*.test 2>/dev/null)

  # 3. Matcha
  for key in "${!all_funcs[@]}"; do
    local file="${key%%|*}"
    local fname="${key##*|}"

    if printf "%s\n" "${tested_funcs[@]}" | grep -Fxq "$fname"; then
      ((testade++))
    else
      ((otestade++))
      untested_by_file["$file"]+="$fname "
    fi
  done

  # Skriv ut resultat
  case "$format" in
    short)
      for file in "${!untested_by_file[@]}"; do
        for f in ${untested_by_file[$file]}; do
          echo "$file:$f"
        done
      done
        echo
        echo "# --- Teststatistik --- "
        echo "# Totalt antal funktioner: $total"
        echo "# Testade:                 $testade"
        echo "# Otestade:                $otestade"

      ;;
    json)
      echo "{"
      local first_file=1
      for file in "${!untested_by_file[@]}"; do
        [[ $first_file -eq 0 ]] && echo ","
        first_file=0
        echo -n "  \"$file\": ["
        local first_func=1
        for f in ${untested_by_file[$file]}; do
          [[ $first_func -eq 0 ]] && echo -n ", "
          first_func=0
          echo -n "\"$f\""
        done
        echo -n "]"
      done
      echo ""
      echo "}"
      ;;
    tree|*)
      # 4. Snygg trädstruktur
      for file in "${!untested_by_file[@]}"; do
        echo "📂 ${file}"
        local funcs=(${untested_by_file[$file]})
        local last=$(( ${#funcs[@]} - 1 ))
        for i in "${!funcs[@]}"; do
          if [[ $i -eq $last ]]; then
            echo "   └── ${funcs[$i]}"
          else
            echo "   ├── ${funcs[$i]}"
          fi
         done
      done

      # Statistik
      echo
      echo "📊 Teststatistik:"
      echo "   Totalt antal funktioner:   $total"
      echo "   ✅ Testade:                 $testade"
      echo "   ❌ Otestade:                $otestade"

      if (( total > 0 )); then
        local percent=$(( 100 * testade / total ))
        echo "   🎯 Täckning:                $percent%"
      fi
      ;;
  esac
}

