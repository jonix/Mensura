#!/usr/bin/env bash
# bash-include-guard.sh (v2, compact)

# ---- Config ----
: "${BASH_GUARD_CACHE_DIR:=${XDG_CACHE_HOME:-$HOME/.cache}/bash-guard}"
mkdir -p -- "$BASH_GUARD_CACHE_DIR" 2>/dev/null || true
: "${FILECACHE_FORCE:=${__BASHGUARD_FORCE:-0}}"
: "${FILECACHE_DEBUG:=${__BASHGUARD_DEBUG:-0}}"

# ---- In-process state ----
declare -gA __INPROC_GUARD_LOADED  2>/dev/null || true
declare -gA __INPROC_GUARD_LOADING 2>/dev/null || true

# ---- Helpers (defined BEFORE use) ----
__bfg_sha1() { command -v sha1sum >/dev/null 2>&1 && sha1sum || shasum -a 1; }
__bfg_stat_mtime() {
  if stat --version >/dev/null 2>&1; then stat -c %Y -- "$1"; else stat -f %m -- "$1"; fi
}
__bfg_realpath() {
  local p="$1"; if command -v realpath >/dev/null 2>&1; then realpath -- "$p" 2>/dev/null && return 0; fi
  local d b; d="$(cd -P -- "$(dirname -- "$p")" && pwd)" || return 1; b="$(basename -- "$p")"; printf '%s/%s\n' "$d" "$b"
}
__bfg_with_lock() {
  # __bfg_with_lock <lockfile> <cmd> [args...]
  local lockfile="$1"; shift
  if command -v flock >/dev/null 2>&1; then
    exec {__bfg_lock_fd}>"$lockfile" 2>/dev/null || { "$@"; return; }
    flock -x "$__bfg_lock_fd" "$@"; local rc=$?; flock -u "$__bfg_lock_fd" || true; return $rc
  fi
  "$@"
}
__bfg_file_id() {
  local src="$1" real id; real="$(__bfg_realpath "$src" 2>/dev/null || printf '%s' "$src")"
  if stat --version >/dev/null 2>&1; then id="$(stat -c '%d:%i' -- "$real")"; else id="$(stat -f '%d:%i' -- "$real")"; fi
  printf '%s\n' "$id"
}

# ---- In-process guard ----
__bash_inproc_guard() {
  local src="${BASH_SOURCE[1]}"; [[ -z "$src" ]] && return 0
  local id; id="$(__bfg_file_id "$src")"
  if [[ -n "${__INPROC_GUARD_LOADING[$id]+x}" ]]; then
    printf '[include-guard] Cirkulärt include: %s\n' "$src" >&2; return 1
  fi
  if [[ -n "${__INPROC_GUARD_LOADED[$id]+x}" && "${FILECACHE_FORCE:-0}" = 0 ]]; then
    return 1
  fi
  __INPROC_GUARD_LOADING["$id"]=1
  return 0
}
__bash_inproc_guard_end() {
  local src="${BASH_SOURCE[1]}"; [[ -z "$src" ]] && return 0
  local id; id="$(__bfg_file_id "$src")"
  __INPROC_GUARD_LOADED["$id"]=1; unset '__INPROC_GUARD_LOADING['"$id"']'
  return 0
}

# ---- File-cache guard ----
__bash_filecache_guard() {
  local source_file="${BASH_SOURCE[1]}"; [[ -z "$source_file" ]] && return 0
  local abs_path; abs_path="$(__bfg_realpath "$source_file" 2>/dev/null || printf '%s' "$source_file")"
  local cache_key cache_file lock_file
  cache_key="$(printf %s "$abs_path" | __bfg_sha1 | awk '{print $1}')" || true
  cache_file="$BASH_GUARD_CACHE_DIR/${cache_key}.cache"; lock_file="$cache_file.lock"
  local mtime; mtime="$(__bfg_stat_mtime "$abs_path" 2>/dev/null || echo '')"

  if [[ -f "$cache_file" ]]; then
    local cache_mtime; cache_mtime="$(head -n1 -- "$cache_file" | awk '{print $2}')"
    if [[ "${FILECACHE_FORCE:-0}" != 0 ]]; then
      [[ "${FILECACHE_DEBUG:-0}" != 0 ]] && echo "[filecache-guard] Force reload: $abs_path"
    elif [[ -n "$mtime" && "$mtime" == "$cache_mtime" ]]; then
      [[ "${FILECACHE_DEBUG:-0}" != 0 ]] && echo "[filecache-guard] Oförändrad: $abs_path – hoppar över."
      return 1
    fi

    # Rensa gamla symboler (utan pipeline-subshell)
    while read -r kind name; do
      [[ -z "$name" ]] && continue
      [[ "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || continue
      if [[ "$kind" == "function" ]]; then unset -f -- "$name" 2>/dev/null || true; else unset -- "$name" 2>/dev/null || true; fi
    done < <(awk '/^(function|variable) / {print $1,$2}' "$cache_file")

    if [[ "${FILECACHE_DEBUG:-0}" != 0 ]]; then
      syms=$(awk '/^(function|variable) / {print $2}' "$cache_file" | xargs 2>/dev/null)
      [[ -n "$syms" ]] && echo "[filecache-guard] Rensade: $syms"
    fi
  fi

  # Skanna nya symboler (hoppa över #-rader). OBS: '{' måste escapas i ERE.
  local -a funclist=() varlist=(); local line
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    if   [[ "$line" =~ ^[[:space:]]*function[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then funclist+=("${BASH_REMATCH[1]}")
    elif [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(\)[[:space:]]*\{ ]]; then funclist+=("${BASH_REMATCH[1]}")
    elif [[ "$line" =~ ^[[:space:]]*([A-Z_][A-Z0-9_]*)= ]]; then varlist+=("${BASH_REMATCH[1]}")
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
    ' _ "$cache_file" "${mtime:-}" "${funclist[@]/#/func:}" "${varlist[@]/#/var:}"

  if [[ "${FILECACHE_DEBUG:-0}" != 0 ]]; then
    echo "[filecache-guard] Uppdaterade cache: $cache_file"
    ((${#funclist[@]})) && echo "[filecache-guard] Funktioner: ${funclist[*]}"
    ((${#varlist[@]})) && echo "[filecache-guard] Variabler:  ${varlist[*]}"
  fi
  return 0
}

# ---- Public API (call these in modules) ----
__bash_include_guard() {
  __bash_inproc_guard       || return 1
  __bash_filecache_guard    || { __bash_inproc_guard_end; return 1; }
  return 0
}
__bash_include_guard_end() { __bash_inproc_guard_end; }

# Back-compat aliases
__bash_guard_begin() { __bash_include_guard; }
__bash_guard_end()   { __bash_include_guard_end; }
