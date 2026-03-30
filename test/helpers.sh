#!/usr/bin/env bash
# Shared container helper functions for BATS test files

start_container() {
    local platform_args=()
    [ -n "${CIPLATFORM:-}" ] && platform_args=(--platform "${CIPLATFORM}")
    docker run -d -t "${platform_args[@]}" -e TZ="Europe/London" "$@" pihole:test
}

wait_for_log() {
    local container="$1"
    local pattern="$2"
    local timeout=60
    local elapsed=0
    printf "Waiting for '%s' in %.30s... " "${pattern}" "${container}"
    until docker logs "${container}" 2>&1 | grep -q "${pattern}"; do
        sleep 1
        elapsed=$(( elapsed + 1 ))
        if (( elapsed >= timeout )); then
            echo "TIMEOUT"
            echo "--- Container logs ---"
            docker logs "${container}"
            return 1
        fi
    done
    echo "ready (${elapsed}s)"
}
