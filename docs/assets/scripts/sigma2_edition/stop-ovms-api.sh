#!/usr/bin/env bash

# OVMS API Stopper - Sigma 2
set -u
umask 077

OVMS_HOME="$HOME/Downloads/ovms"
PID_FILE="$HOME/.ovms-api.pid"
LOCK_FILE="$HOME/.ovms-api.lock"
LOG_FILE="$HOME/ovms.log"
WAIT_SECONDS=30

finish() {
    local status=$?
    trap - EXIT
    exec 9>&-
    echo
    if [[ -t 0 ]]; then
        read -r -n 1 -s -p "Press any key to close this window..." || true
        echo
    fi
    exit "$status"
}

fail() {
    echo "[ERROR] $*"
    echo "Log: $LOG_FILE"
    exit 1
}

process_start() {
    local stat
    local -a fields
    [[ "$1" =~ ^[0-9]+$ && "$1" -gt 1 ]] || return 1
    [[ -O "/proc/$1" ]] || return 1
    IFS= read -r stat 2>/dev/null < "/proc/$1/stat" || return 1
    read -r -a fields <<< "${stat##*) }"
    [[ "${fields[0]:-Z}" != Z && -n "${fields[19]:-}" ]] || return 1
    printf '%s\n' "${fields[19]}"
}

matches_process() {
    [[ "$pid" =~ ^[0-9]+$ && "$pid" -gt 1 && "$started" =~ ^[0-9]+$ ]] || return 1
    [[ "$(process_start "$pid")" == "$started" ]] || return 1
    [[ "$(readlink -f "/proc/$pid/exe" 2>/dev/null)" == "$OVMS_HOME/bin/ovms" ]]
}

main() {
    local command extra deadline
    echo "[INFO] Checking OVMS service status..."
    for command in flock readlink; do
        command -v "$command" >/dev/null 2>&1 || fail "Required command not found: $command"
    done
    exec 9>"$LOCK_FILE" || fail "Cannot open $LOCK_FILE"
    flock -n 9 || fail "Another OVMS start/stop operation is in progress."

    if [[ ! -f "$PID_FILE" ]]; then
        echo "[INFO] No managed OVMS PID file found. No process was stopped."
        echo "If you started OVMS in a terminal, stop it there."
        return 0
    fi
    read -r pid started extra < "$PID_FILE" || fail "Cannot read $PID_FILE"
    [[ "$pid" =~ ^[0-9]+$ && "$pid" -gt 1 && "$started" =~ ^[0-9]+$ && -z "$extra" ]] \
        || fail "Invalid PID file; no process was stopped: $PID_FILE"
    if ! process_start "$pid" >/dev/null; then
        rm -f -- "$PID_FILE" || fail "Cannot remove stale PID file."
        echo "[INFO] The recorded OVMS process is no longer running. Removed its stale PID file."
        return 0
    fi
    matches_process || fail "PID $pid does not match the recorded OVMS instance. No process was stopped."

    echo "[INFO] Stopping OVMS (PID $pid)..."
    kill -TERM "$pid" || fail "Could not stop OVMS (PID $pid)."
    deadline=$((SECONDS + WAIT_SECONDS))
    while (( SECONDS < deadline )); do
        if ! matches_process; then
            rm -f -- "$PID_FILE" || fail "OVMS stopped, but its PID file could not be removed."
            echo "[OK] OVMS stopped."
            echo "To start again, double-click Start OVMS API."
            return 0
        fi
        sleep 1
    done
    fail "OVMS has not stopped after $WAIT_SECONDS seconds. The PID file was kept; check the log before retrying."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    trap finish EXIT
    main
fi
