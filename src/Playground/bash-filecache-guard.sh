#!/usr/bin/env bash

# Enkel, cache-baserad include-guard för Bash.
# Extraherar funktioner och variabler från modulfiler och cachar dem.
# Vid reload tas gamla funktioner och variabler bort – utan Bash-magi!

# Exempel på användning i modul:
#----- Copy ----
## Se till att denna file laddas in en och endast en gång
# source "$(dirname "${BASH_SOURCE[0]}")/bash-filecache-guard.sh" || return
# __bash_filecache_guard || return
# #   ...din kod...
# ---- End copy ---
#
#
# Vid testning på prompt: Om du vill tvinga omladdning av scriptet kör
# $>__FILECACHE_FORCE=1 source ./frotz.sh
#
# Om du vill ha statistik, sätt miiljövariabeln
# FILECACHE_DEBUG=1

# Var ska cache lagras? (XDG eller temp)
: "${BASH_GUARD_CACHE_DIR:=${XDG_CACHE_HOME:-$HOME/.cache}/bash-guard}"
mkdir -p "$BASH_GUARD_CACHE_DIR"

: "${BASH_GUARD_CACHE_DIR:=${XDG_CACHE_HOME:-$HOME/.cache}/bash-guard}"
mkdir -p "$BASH_GUARD_CACHE_DIR"

function __bash_filecache_guard() {
    local source_file="${BASH_SOURCE[1]}"
    local abs_path
    abs_path="$(realpath "$source_file" 2>/dev/null)" || abs_path="$source_file"

    local cache_key
    cache_key="$(echo -n "$abs_path" | sha1sum | awk '{print $1}')"
    local cache_file="$BASH_GUARD_CACHE_DIR/${cache_key}.cache"

    local FORCE="${__BASHGUARD_FORCE:-0}"
    local DEBUG="${__BASHGUARD_DEBUG:-0}"

    # Hämta filens mtime
    local mtime
    if stat --version >/dev/null 2>&1; then
        mtime=$(stat -c %Y "$abs_path" 2>/dev/null)
    else
        mtime=$(stat -f %m "$abs_path" 2>/dev/null)
    fi

    # Ladda och rensa om cache finns och mtime skiljer sig, eller vid force
    if [[ -f "$cache_file" ]]; then
        local cache_mtime
        cache_mtime=$(head -n1 "$cache_file" | cut -d' ' -f2)
        if [[ "$FORCE" != "0" ]] ; then
            [[ "$DEBUG" != "0" ]] && echo "[filecache-guard] Force reload script"
        fi

        if [[ "$mtime" == "$cache_mtime" && "$FORCE" = "0" ]]; then
            [[ "$DEBUG" != "0" ]] && echo "[filecache-guard] $abs_path: Ingen ändring – hoppar över."
            return 1
        fi

        # Läs gamla funktions- och variabelnamn från cache och rensa
        awk '/^function /{print $2} /^variable /{print $2}' "$cache_file" | while read -r name; do
            if [[ "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                if grep -q "^function $name" "$cache_file"; then
                    unset -f "$name"
                else
                    unset "$name"
                fi
            fi
        done
        [[ "$DEBUG" != "0" ]] && echo "[filecache-guard] Rensade gamla namn enligt cache: $(awk '/^function / || /^variable /{print $2}' "$cache_file" | xargs)"
    fi

    # Kör regex mot filen för att hitta funktioner och variabler, men hoppa över utkommenterade rader
    local funclist varlist line
    funclist=""
    varlist=""
    while IFS= read -r line; do
        # Skippa utkommenterade rader
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        if [[ "$line" =~ ^[[:space:]]*function[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
            funclist+=" ${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(\)[[:space:]]*{ ]]; then
            funclist+=" ${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^[[:space:]]*([A-Z_][A-Z0-9_]*)= ]]; then
            varlist+=" ${BASH_REMATCH[1]}"
        fi
    done < "$abs_path"

    # Uppdatera cachefilen
    {
        echo "mtime $mtime"
        for f in $funclist; do echo "function $f"; done
        for v in $varlist; do echo "variable $v"; done
    } > "$cache_file"
    [[ "$DEBUG" != "0" ]] && echo "[filecache-guard] Uppdaterade cache: $cache_file"
    [[ "$DEBUG" != "0" ]] && echo "[filecache-guard] Funktionsnamn: $funclist"
    [[ "$DEBUG" != "0" ]] && echo "[filecache-guard] Variabelnamn: $varlist"

    return 0
}


function __bash_guard_filecache__deprecated() {
    local source_file="${BASH_SOURCE[1]}"
    local abs_path
    abs_path="$(realpath "$source_file" 2>/dev/null)" || abs_path="$source_file"

    local cache_key
    cache_key="$(echo -n "$abs_path" | sha1sum | awk '{print $1}')"
    local cache_file="$BASH_GUARD_CACHE_DIR/${cache_key}.cache"

    # Hämta filens mtime
    local mtime
    if stat --version >/dev/null 2>&1; then
        mtime=$(stat -c %Y "$abs_path" 2>/dev/null)
    else
        mtime=$(stat -f %m "$abs_path" 2>/dev/null)
    fi

    # Ladda och rensa om cache finns och mtime skiljer sig
    if [[ -f "$cache_file" ]]; then
        local cache_mtime
        cache_mtime=$(head -n1 "$cache_file" | cut -d' ' -f2)
        if [[ "$mtime" == "$cache_mtime" ]]; then
            echo "[filecache-guard] $abs_path: Ingen ändring – hoppar över."
            return 1
        fi

        # Läs gamla funktions- och variabelnamn från cache och rensa
        awk '/^function /{print $2} /^variable /{print $2}' "$cache_file" | while read -r name; do
            if [[ "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                if grep -q "^function $name" "$cache_file"; then
                    unset -f "$name"
                else
                    unset "$name"
                fi
            fi
        done
        echo "[filecache-guard] Rensade gamla namn enligt cache: $(awk '/^function / || /^variable /{print $2}' "$cache_file" | xargs)"
    fi

    # Kör regex mot filen för att hitta funktioner och variabler
    local funclist varlist line
    funclist=""
    varlist=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*function[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
            funclist+=" ${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(\)[[:space:]]*{ ]]; then
            funclist+=" ${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^[[:space:]]*([A-Z_][A-Z0-9_]*)= ]]; then
            varlist+=" ${BASH_REMATCH[1]}"
        fi
    done < "$abs_path"

    # Uppdatera cachefilen
    {
        echo "mtime $mtime"
        for f in $funclist; do echo "function $f"; done
        for v in $varlist; do echo "variable $v"; done
    } > "$cache_file"
    echo "[filecache-guard] Uppdaterade cache: $cache_file"
    echo "[filecache-guard] Funktionsnamn: $funclist"
    echo "[filecache-guard] Variabelnamn: $varlist"

    return 0
}
