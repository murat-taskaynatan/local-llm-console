#!/bin/bash
set -euo pipefail

ELECTRON_PID="${1:-}"
TARGET_TITLE="${CODEX_DESKTOP_RUNTIME_NAME:-Local LLM Console}"
ATTEMPTS="${CODEX_DESKTOP_X11_TITLE_FIX_ATTEMPTS:-200}"
SLEEP_SECONDS="${CODEX_DESKTOP_X11_TITLE_FIX_SLEEP_SECONDS:-0.2}"

if [[ -z "$ELECTRON_PID" ]]; then
    exit 0
fi

if [[ -z "${DISPLAY:-}" ]]; then
    exit 0
fi

if [[ -n "${XDG_SESSION_TYPE:-}" ]] && [[ "${XDG_SESSION_TYPE:-}" != "x11" ]]; then
    exit 0
fi

if ! command -v xprop >/dev/null 2>&1; then
    exit 0
fi

collect_relevant_pids() {
    local queue current children child
    local -A seen=()

    queue=("$ELECTRON_PID")
    while ((${#queue[@]} > 0)); do
        current="${queue[0]}"
        queue=("${queue[@]:1}")

        [[ -n "$current" ]] || continue
        [[ -n "${seen[$current]:-}" ]] && continue
        seen["$current"]=1
        printf '%s\n' "$current"

        children="$(pgrep -P "$current" 2>/dev/null || true)"
        while IFS= read -r child; do
            [[ -n "$child" ]] || continue
            [[ -n "${seen[$child]:-}" ]] && continue
            queue+=("$child")
        done <<< "$children"
    done
}

find_window_ids_for_pid() {
    local window_ids id props
    local -A valid_pids=()
    local candidate_pid

    while IFS= read -r candidate_pid; do
        [[ -n "$candidate_pid" ]] || continue
        valid_pids["$candidate_pid"]=1
    done < <(collect_relevant_pids)

    window_ids="$(xprop -root _NET_CLIENT_LIST_STACKING 2>/dev/null | sed 's/.*# //' | tr ',' ' ')"
    for id in $window_ids; do
        props="$(xprop -id "$id" _NET_WM_PID 2>/dev/null || true)"
        candidate_pid="$(sed -n 's/^_NET_WM_PID(CARDINAL) = //p' <<< "$props" | tr -d '[:space:]')"
        if [[ -n "$candidate_pid" ]] && [[ -n "${valid_pids[$candidate_pid]:-}" ]]; then
            printf '%s\n' "$id"
        fi
    done
}

set_window_title() {
    local id="$1"

    if command -v wmctrl >/dev/null 2>&1; then
        wmctrl -i -r "$id" -T "$TARGET_TITLE" >/dev/null 2>&1 || true
    fi

    xprop -id "$id" -f _NET_WM_NAME 8u -set _NET_WM_NAME "$TARGET_TITLE" >/dev/null 2>&1 || true
    xprop -id "$id" -f WM_NAME 8u -set WM_NAME "$TARGET_TITLE" >/dev/null 2>&1 || true
}

attempt=0
while (( attempt < ATTEMPTS )); do
    if ! kill -0 "$ELECTRON_PID" >/dev/null 2>&1; then
        exit 0
    fi

    while IFS= read -r id; do
        [[ -n "$id" ]] || continue
        set_window_title "$id"
    done < <(find_window_ids_for_pid)

    attempt=$((attempt + 1))
    sleep "$SLEEP_SECONDS"
done

exit 0
