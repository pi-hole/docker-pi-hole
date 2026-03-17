#!/usr/bin/env bash
set -euo pipefail

# Run from the test/ directory regardless of where the script is called from
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ---- Build the image --------------------------------------------------------

PLATFORM_ARGS=()
[ -n "${CIPLATFORM:-}" ] && PLATFORM_ARGS=(--platform "${CIPLATFORM}")

docker buildx build \
    --load \
    "${PLATFORM_ARGS[@]}" \
    --progress plain \
    -f ../src/Dockerfile \
    -t pihole:test \
    ../src/

# ---- Install BATS -----------------------------------------------------------

if [ -z "${BATS:-}" ]; then
    mkdir -p libs
    if [ ! -d libs/bats ]; then
        git clone --depth=1 --quiet https://github.com/bats-core/bats-core libs/bats
    fi
    BATS=libs/bats/bin/bats
fi

# ---- Start containers -------------------------------------------------------

# Cleanup all test containers on exit (success or failure)
CONTAINERS=()
cleanup() {
    if [ ${#CONTAINERS[@]} -gt 0 ]; then
        docker rm -f "${CONTAINERS[@]}" > /dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

start_container() {
    local id
    id=$(docker run -d -t "${PLATFORM_ARGS[@]}" -e TZ="Europe/London" "$@" pihole:test)
    CONTAINERS+=("$id")
    echo "$id"
}

CONTAINER_DEFAULT=$(start_container)
CONTAINER_CUSTOM=$(start_container \
    -e PIHOLE_UID=456 \
    -e PIHOLE_GID=456 \
    -e FTLCONF_webserver_api_password=1234567890)

export CONTAINER_DEFAULT CONTAINER_CUSTOM CIPLATFORM

# ---- Wait for containers to be ready ----------------------------------------

wait_for_ftl() {
    local container="$1"
    local timeout=60
    local elapsed=0
    printf "Waiting for FTL in %.12s... " "${container}"
    until docker logs "${container}" 2>&1 | grep -q "########## FTL started"; do
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

for container in "$CONTAINER_DEFAULT" "$CONTAINER_CUSTOM"; do
    wait_for_ftl "$container"
done

# ---- Run BATS ---------------------------------------------------------------

# Use pretty formatter when stdout is a TTY; fall back to TAP in CI / pipes
if [ -t 1 ]; then
    "$BATS" --pretty test_suite.bats
else
    "$BATS" --formatter tap test_suite.bats
fi
