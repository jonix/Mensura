#!/usr/bin/env bash
# bash-include-guard.sh
#
# Kombinerad include-guard för Bash:
#  - In-process guard: hindrar dubbel-source och cirkulära beroenden i samma shell.
#  - File-cache guard: hoppar över (re)load om källfilens mtime är oförändrad,
#    och städar bort gamla funktioner/variabler vid omladdning.
#
# Returkontrakt (för __bash_include_guard / __bash_filecache_guard / __bash_inproc_guard):
#   0 = kör modulens kod (ny/ändrad)
#   1 = hoppa över (redan laddad/oförändrad) eller fel (cirkulärt include): använd "|| return"
#
# Miljövariabler:
#   BASH_GUARD_CACHE_DIR  - cachekatalog (default: $XDG_CACHE_HOME/bash-guard eller ~/.cache/bash-guard)
#   FILECACHE_DEBUG       - 1 => verbose
#   FILECACHE_FORCE       - 1 => tvinga omladdning trots cache/in-process
#
# Portabilitet:
#   - GNU/BSD stat
#   - sha1sum eller shasum -a 1
#   - flock används om tillgängligt (best-effort)

# -- Config & cache dir (XDG, annars ~/.cache)
: "${BASH_GUARD_CACHE_DIR:=${XDG_CACHE_HOME:-$HOME/.cache}/bash-guard}"
mkdir -p -- "$BASH_GUARD_CACHE_DIR" 2>/dev/null || true

# Läs vänliga flaggor (fallback mot ev. äldre interna namn)
: "${FILECACHE_FORCE:=${__BASHGUARD_FORCE:-0}}"
: "${FILECACHE_DEBUG:=${__BASHGUARD_DEBUG:-0}}"

# -- Globala tabeller för in-process guard
declare -gA __INPROC_GUARD_LOADED  2>/dev/null || true
declare -gA __INPROC_GUARD_LOADING 2>/dev/null || true

# ---------- Hjälpfunktioner ----------
__bfg_sha1() { if command -v sha1sum >/dev/null 2>&1; then sha1sum; else shasum -a 1; fi; }

__bfg_stat_mtime() {
  if stat --version >/dev/null 2>&1; then
    stat -c %Y -- "$1"
  else
    stat -f %m -- "$1"
  fi
}

__bfg_realpath() {
  # Robust realpath: försök realpath, annars cd -P
  local p="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath -- "$p" 2>/dev/null && return 0
  fi
  local d b
  d="$(cd -P -- "$(dirname -- "$p")" && pwd)" || return 1
  b="$(basename -- "$p")"
  printf '%s/%s\n' "$d" "$b"
}

__bfg_with_lock() {
  # __bfg_with_lock <lockfile> <command> [args...]
  local lockfile="$1"; shift
  if command -v flock >/dev/null 2>&1; then
    exec {__bfg_lock_fd}>"$lockfile" 2>/dev/null || { "$@"; return; }
    flock -x "$__bfg_lock_fd" "$@"
    flock -u "$__bfg_lock_fd" || true
  else
    "$@"
  fi
}

__bfg_file_id() {
  # Stabilt ID per fil (device:inode) för symlänk-säkerhet
  local src="$1" real id
  real="$(__bfg_realpath "$src" 2>/dev/null || printf '%s' "$src")"
  if stat --version >/dev/null 2>&1; then
    id="$(stat -c '%d:%i' -- "$real")"
  else
    id="$(stat -f '%d:%i' -- "$real")"
  fi
  printf '%s\n' "$id"
}

# ---------- In-process guard ----------
__bash_inproc_guard() {
  # Kallas överst i modulen. Stoppar cirklar och dubbel-source i samma shell.
  local src="${BASH_SOURCE[1]}"
  [[ -z "$src" ]] && return 0
  local id; id="$(__bfg_file_id "$src")"

  # Cirkulärt include (A -> B -> A)
  if [[ -n "${__INPROC_GUARD_LOADING[$id]+x}" ]]; then
    printf '[include-guard] Cirkulärt include: %s\n' "$src" >&2
    return 1
  fi

  # Redan laddad och ingen force -> hoppa över
  if [[ -n "${__INPROC_GUARD_LOADED[$id]+x}" && "${FILECACHE_FORCE:-0}" = 0 ]]; then
    return 1
  fi

  # Markera pågående laddning
  __INPROC_GUARD_LOADING["$id"]=1
  return 0
}

__bash_inproc_guard_end() {
  # Kallas i slutet av modulen när den faktiskt exekverats klart.
  local src="${BASH_SOURCE[1]}"
  [[ -z "$src" ]] && return 0
  local id; id="$(__bfg_file_id "$src")"
  __INPROC_GUARD_LOADED["$id"]=1
  unset '__INPROC_GUARD_LOADING['"$id"']'
  return 0
}

# ---------- File-cache guard ----------
__bash_filecache_guard() {
  # Returnerar 1 om oförändrad (hoppa över), 0 om ny/ändrad (kör modul),
  # och städar gamla symboler vid omladdning.
  local source_file="${BASH_SOURCE[1]}"
  [[ -z "$source_file" ]] && return 0

  local abs_path
  abs_path="$(__bfg_realpath "$source_file" 2>/dev/null || printf '%s' "$source_file")"

  local cache_key cache_file lock_file
  cache_key="$(printf %s "$abs_path" | __bfg_sha1 | awk '{print $1}')"
  cache_file="$BASH_GUARD_CACHE_DIR/${cache_key}.cache"
  lock_file="$cache_file.lock"

  local mtime; mtime="$(__bfg_stat_mtime "$abs_path" 2>/dev/null || echo '')"

  # Om cache finns och mtime matchar (och ingen FORCE) -> hoppa över
  if [[ -f "$cache_file" ]]; then
    local cache_mtime
    cache_mtime="$(head -n1 -- "$cache_file" | awk '{print $2}')"
    if [[ "${FILECACHE_FORCE:-0}" != 0 ]]; then
      [[ "${FILECACHE_DEBUG:-0}" != 0 ]] && echo "[filecache-guard] Force reload: $abs_path"
    elif [[ -n "$mtime" && "$mtime" == "$cache_mtime" ]]; then
      [[ "${FILECACHE_DEBUG:-0}" != 0 ]] && echo "[filecache-guard] Oförändrad: $abs_path – hoppar över."
      return 1
    fi

    # Rensa gamla symboler (i samma shell: process substitution, ej pipeline)
    while read -r kind name; do
      [[ -z "$name" ]] && continue
      [[ "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || continue
      if [[ "$kind" == "function" ]]; then
        unset -f -- "$name" 2>/dev/null || true
      else
        unset -- "$name" 2>/dev/null || true
      fi
    done < <(awk '/^(function|variable) / {print $1,$2}'  "$cache_file")

    if [[ "${FILECACHE_DEBUG:-0}" != 0 ]]; then
      syms=$(awk '/^(function|variable) / {print $2}'  "$cache_file" | xargs 2>/dev/null)
      [[ -n "$syms" ]] && echo "[filecache-guard] Rensade: $syms"
    fi
  fi

  # Plocka nya symboler från filen (skippa #-rader)
  local -a funclist=() varlist=()
  local line
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    if [[ "$line" =~ ^[[:space:]]*function[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
      funclist+=("${BASH_REMATCH[1]}")
    elif [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(\)[[:space:]]*\{ ]]; then
      funclist+=("${BASH_REMATCH[1]}")
    elif [[ "$line" =~ ^[[:space:]]*([A-Z_][A-Z0-9_]*)= ]]; then
      varlist+=("${BASH_REMATCH[1]}")
    fi
  done < "$abs_path"

  # Skriv cache atomärt under lås
  __bfg_with_lock "$lock_file" \
    bash -c '
      set -euo pipefail
      cache_file="$1"; mtime="$2"; shift 2
      tmp="${cache_file}.tmp.$$"
      {
        echo "mtime $mtime"
        for f in "$@"; do
          case "$f" in
            func:*) echo "function ${f#func:}" ;;
            var:*)  echo "variable ${f#var:}" ;;
          esac
        done
      } > "$tmp"
      mv -f -- "$tmp" "$cache_file"
    ' _ "$cache_file" "${mtime:-}" \
      "${funclist[@]/#/func:}" "${varlist[@]/#/var:}"

  if [[ "${FILECACHE_DEBUG:-0}" != 0 ]]; then
    echo "[filecache-guard] Uppdaterade cache: $cache_file"
    ((${#funclist[@]})) && echo "[filecache-guard] Funktioner: ${funclist[*]}"
    ((${#varlist[@]})) && echo "[filecache-guard] Variabler:  ${varlist[*]}"
  fi

  return 0
}

# ---------- Publikt wrapper-API ----------
__bash_include_guard() {
  # Kallas överst i modulen: kombinerar in-process + file-cache.
  # Retur 1 => hoppa över modulens kod.
  __bash_inproc_guard || return 1

  # Om file-cache säger "oförändrad", markera direkt som laddad och hoppa över.
  __bash_filecache_guard || { __bash_inproc_guard_end; return 1; }

  # Annars: modulens kod ska köras, och i slutet ska __bash_include_guard_end anropas.
  return 0
}

__bash_include_guard_end() {
  # Kallas i slutet av modulen när den verkligen exekverats klart.
  __bash_inproc_guard_end
}

# (valfritt) bakåtkompatibla alias
__bash_guard_begin() { __bash_include_guard; }
__bash_guard_end()   { __bash_include_guard_end; }
