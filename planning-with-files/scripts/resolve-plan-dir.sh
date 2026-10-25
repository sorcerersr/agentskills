#!/bin/sh
# planning-with-files: resolve active plan directory.
#
# Resolution order:
#   1. $PLAN_ID env var → ./.planning/$PLAN_ID/ if exists
#   2. ./.planning/.active_plan content → matching dir if exists
#   3. Newest ./.planning/<dir>/ by file activity
#   4. Multi-project: CWD has no plan of its own → scan immediate subdirs
#      for a */.planning/ with a plan, pick the most recently active one
#   5. Otherwise empty stdout (caller falls back to legacy ./task_plan.md)
#
# Always exits 0. Never errors out the agent loop.
#
# Usage:
#   PLAN_DIR="$(sh scripts/resolve-plan-dir.sh)"
#   PLAN_FILE="${PLAN_DIR:+$PLAN_DIR/}task_plan.md"

set -u

PLAN_ROOT="${1:-${PWD}/.planning}"

# Plan-id safe-identifier check. Rejects whitespace, path separators, leading
# dots, and empty strings; accepts the YYYY-MM-DD-<slug> shape from
# init-session.sh as well as legacy hand-created names like "alpha" or
# "feature-foo". The intent is to filter garbage content (e.g. a corrupt
# .active_plan file containing only whitespace or random text) without
# enforcing a date prefix that would break backward compatibility.
SLUG_RE='^[A-Za-z0-9_][A-Za-z0-9._-]*$'

slug_is_valid() {
    case "$1" in
        '') return 1 ;;
    esac
    printf "%s" "$1" | grep -Eq "${SLUG_RE}"
}

# Portable mtime resolver. Tries GNU stat, BSD stat, BSD/macOS date -r,
# python3, then perl. Returns "0" on full miss so callers can sort.
mtime_of() {
    target="$1"
    out="$(stat -c '%Y' "${target}" 2>/dev/null)"
    if [ -n "${out}" ]; then printf "%s\n" "${out}"; return 0; fi
    out="$(stat -f '%m' "${target}" 2>/dev/null)"
    if [ -n "${out}" ]; then printf "%s\n" "${out}"; return 0; fi
    out="$(date -r "${target}" +%s 2>/dev/null)"
    if [ -n "${out}" ]; then printf "%s\n" "${out}"; return 0; fi
    if command -v python3 >/dev/null 2>&1; then
        out="$(python3 -c "import os,sys;print(int(os.stat(sys.argv[1]).st_mtime))" "${target}" 2>/dev/null)"
        if [ -n "${out}" ]; then printf "%s\n" "${out}"; return 0; fi
    fi
    if command -v python >/dev/null 2>&1; then
        out="$(python -c "import os,sys;print(int(os.stat(sys.argv[1]).st_mtime))" "${target}" 2>/dev/null)"
        if [ -n "${out}" ]; then printf "%s\n" "${out}"; return 0; fi
    fi
    if command -v perl >/dev/null 2>&1; then
        out="$(perl -e 'print((stat shift)[9])' "${target}" 2>/dev/null)"
        if [ -n "${out}" ]; then printf "%s\n" "${out}"; return 0; fi
    fi
    printf "0\n"
}

# Max mtime of the files inside a plan dir (including hidden files like
# .hook_state). A dir's own mtime only changes when entries are added or
# removed, not when a file is edited in place, so the max file mtime is the
# real "last touched" signal. Returns "0" for a dir with no files.
plan_activity() {
    dir="$1"
    max=0
    for f in "$dir"/* "$dir"/.*; do
        [ -f "$f" ] || continue
        case "$(basename "$f")" in
            . | ..) continue ;;
        esac
        m="$(mtime_of "$f")"
        if [ "$m" -gt "$max" ] 2>/dev/null; then
            max="$m"
        fi
    done
    printf "%s\n" "$max"
}

# Resolve a plan within a given plan root: .active_plan first, then newest by
# file activity. Prints the plan dir on success, nothing on miss.
resolve_in_root() {
    root="$1"
    # .active_plan
    active_file="${root}/.active_plan"
    if [ -f "$active_file" ]; then
        plan_id="$(tr -d '\r\n[:space:]' < "$active_file")"
        if slug_is_valid "$plan_id"; then
            candidate="${root}/${plan_id}"
            if [ -d "$candidate" ]; then
                printf "%s\n" "$candidate"
                return 0
            fi
        fi
    fi
    # Newest by file activity
    [ -d "$root" ] || return 1
    latest=""
    latest_mtime=0
    for entry in "${root}"/*/; do
        [ -d "$entry" ] || continue
        clean="${entry%/}"
        name="$(basename "$clean")"
        case "$name" in
            .*) continue ;;
        esac
        slug_is_valid "$name" || continue
        [ -f "${clean}/task_plan.md" ] || continue
        mtime="$(plan_activity "$clean")"
        if [ "$mtime" -gt "${latest_mtime}" ] 2>/dev/null; then
            latest_mtime="${mtime}"
            latest="${clean}"
        fi
    done
    if [ -n "$latest" ]; then
        printf "%s\n" "$latest"
        return 0
    fi
    return 1
}

# Multi-project fallback: the CWD has no plan of its own, so scan immediate
# subdirectories for a .planning/ with a plan and pick the most recently
# active one. Depth 1 only; hidden subdirs are skipped. On a tie, the
# alphabetically-first plan slug wins (deterministic).
resolve_subdirs() {
    base="${PWD}"
    best=""
    best_mtime=0
    for subdir in "${base}"/*/; do
        [ -d "$subdir" ] || continue
        name="$(basename "${subdir%/}")"
        case "$name" in
            .*) continue ;;
        esac
        root="${subdir}.planning"
        [ -d "$root" ] || continue
        candidate="$(resolve_in_root "$root")"
        [ -n "$candidate" ] || continue
        m="$(plan_activity "$candidate")"
        if [ "$m" -gt "$best_mtime" ] 2>/dev/null; then
            best_mtime="$m"
            best="$candidate"
        elif [ "$m" -eq "$best_mtime" ] 2>/dev/null && [ -n "$best" ]; then
            first="$(printf '%s\n%s\n' "$(basename "$candidate")" "$(basename "$best")" | sort | head -1)"
            if [ "$first" = "$(basename "$candidate")" ]; then
                best="$candidate"
            fi
        fi
    done
    if [ -n "$best" ]; then
        printf "%s\n" "$best"
        return 0
    fi
    return 1
}

# 1. $PLAN_ID env → CWD's .planning/
plan_id="${PLAN_ID:-}"
if slug_is_valid "$plan_id"; then
    candidate="${PLAN_ROOT}/${plan_id}"
    if [ -d "$candidate" ]; then
        printf "%s\n" "$candidate"
        exit 0
    fi
fi
# 2+3. CWD's .planning/ (.active_plan, then newest by activity)
if candidate="$(resolve_in_root "$PLAN_ROOT")" && [ -n "$candidate" ]; then
    printf "%s\n" "$candidate"
    exit 0
fi
# 4. Multi-project: immediate subdirs
if candidate="$(resolve_subdirs)" && [ -n "$candidate" ]; then
    printf "%s\n" "$candidate"
    exit 0
fi
# 5. Empty
exit 0
