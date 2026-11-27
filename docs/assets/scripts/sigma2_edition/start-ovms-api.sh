#!/usr/bin/env bash

# OVMS API Starter - Sigma 2
set -u
umask 077

# ---------- Environment setup ----------
unset LD_LIBRARY_PATH
export OVMS_HOME="$HOME/Downloads/ovms"
export PATH="$OVMS_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$OVMS_HOME/lib"

MODEL_PATH="$HOME/models/OpenVINO/Qwen3.6-35B-A3B-int4-ov"
API_URL="http://localhost:8080/v3"
LOG_FILE="$HOME/ovms.log"
PID_FILE="$HOME/.ovms-api.pid"
LOCK_FILE="$HOME/.ovms-api.lock"
WAIT_SECONDS=300

# ---------- Helper functions ----------
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

# Check both executable and start time so a reused PID is never trusted alone.
matches_process() {
    [[ "$pid" =~ ^[0-9]+$ && "$pid" -gt 1 && "$started" =~ ^[0-9]+$ ]] || return 1
    [[ "$(process_start "$pid")" == "$started" ]] || return 1
    [[ "$(readlink -f "/proc/$pid/exe" 2>/dev/null)" == "$OVMS_HOME/bin/ovms" ]]
}

api_ready() {
    local response
    response=$(curl --noproxy '*' -fsS --connect-timeout 1 --max-time 2 \
        "$API_URL/models" 2>/dev/null) || return 1
    grep -qE '"id"[[:space:]]*:[[:space:]]*"qwen"' <<< "$response"
}

wait_for_api() {
    local deadline=$((SECONDS + WAIT_SECONDS))
    echo "[INFO] Waiting for qwen to load (up to $WAIT_SECONDS seconds)..."
    while (( SECONDS < deadline )); do
        if ! matches_process; then
            rm -f -- "$PID_FILE"
            fail "OVMS exited before the API was ready. Check the log."
        fi
        if api_ready && matches_process; then
            echo
            echo "============================================"
            echo "[OK] OVMS is ready"
            echo "API: $API_URL"
            echo "Log: $LOG_FILE"
            echo "PID: $pid"
            echo "============================================"
            return 0
        fi
        sleep 2
        printf '.'
    done
    echo
    fail "The API is not ready yet. OVMS may still be loading; check the log, then retry or use Stop OVMS API."
}

main() {
    local command listeners extra
    echo "[INFO] Checking OVMS service status..."
    for command in curl ss flock readlink grep nohup; do
        command -v "$command" >/dev/null 2>&1 || fail "Required command not found: $command"
    done

    # Serialize starts/stops, including simultaneous desktop launches.
    exec 9>"$LOCK_FILE" || fail "Cannot open $LOCK_FILE"
    flock -n 9 || fail "Another OVMS start/stop operation is in progress."

    if [[ -f "$PID_FILE" ]]; then
        read -r pid started extra < "$PID_FILE" || fail "Cannot read $PID_FILE"
        [[ "$pid" =~ ^[0-9]+$ && "$pid" -gt 1 && "$started" =~ ^[0-9]+$ && -z "$extra" ]] \
            || fail "Invalid PID file: $PID_FILE"
        if matches_process; then
            echo "[INFO] OVMS is already running (PID $pid); checking its API."
            wait_for_api
            return
        fi
        if process_start "$pid" >/dev/null; then
            fail "The PID file no longer matches this OVMS instance. No new process was started."
        fi
        rm -f -- "$PID_FILE" || fail "Cannot remove stale PID file."
    fi

    listeners=$(ss -H -ltn 'sport = :8080') || fail "Cannot check port 8080."
    if [[ -n "$listeners" ]]; then
        if api_ready; then
            echo "[INFO] An API serving qwen is already available at $API_URL."
            echo "No new process was started. This service is not managed by these scripts; stop it where it was started."
            return 0
        fi
        fail "Port 8080 is in use, but the qwen API is not ready. Check the existing service before retrying."
    fi

    [[ -x "$OVMS_HOME/bin/ovms" ]] || fail "OVMS executable not found: $OVMS_HOME/bin/ovms"
    [[ -d "$MODEL_PATH" ]] || fail "Local model not found: $MODEL_PATH. Complete the model download first."
    : > "$LOG_FILE" || fail "Cannot write $LOG_FILE"
    : > "$PID_FILE" || fail "Cannot write $PID_FILE"

    echo "[INFO] Starting OVMS with the local model..."
    nohup "$OVMS_HOME/bin/ovms" --rest_port 8080 \
        --model_repository_path "$HOME/models" \
        --model_path "$MODEL_PATH" \
        --model_name qwen \
        --reasoning_parser qwen3 \
        --tool_parser qwen3coder \
        --target_device GPU \
        --task text_generation > "$LOG_FILE" 2>&1 < /dev/null 9>&- &
    pid=$!
    started=$(process_start "$pid") || {
        rm -f -- "$PID_FILE"
        fail "OVMS could not be started. Check the log."
    }
    printf '%s %s\n' "$pid" "$started" > "$PID_FILE" || fail "Cannot save the OVMS PID."

    # Allow nohup to replace itself with the OVMS executable.
    sleep 1
    wait_for_api
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    trap finish EXIT
    main
fi
