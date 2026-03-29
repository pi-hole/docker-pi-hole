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
        git clone --depth=1 --quiet --branch "${BATS_VERSION:-v1.13.0}" https://github.com/bats-core/bats-core libs/bats
    fi
    if [ ! -d libs/bats-support ]; then
        git clone --depth=1 --quiet --branch "${BATS_SUPPORT_VERSION:-v0.3.0}" https://github.com/bats-core/bats-support libs/bats-support
    fi
    if [ ! -d libs/bats-assert ]; then
        git clone --depth=1 --quiet --branch "${BATS_ASSERT_VERSION:-v2.2.4}" https://github.com/bats-core/bats-assert libs/bats-assert
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
    -e FTLCONF_webserver_api_password=1234567890 \
    -e FTLCONF_webserver_port=8080 \
    -e FTLCONF_dns_upstreams="8.8.8.8;1.1.1.1")
CONTAINER_PACKAGES=$(start_container \
    -e ADDITIONAL_PACKAGES=wget)

export CONTAINER_DEFAULT CONTAINER_CUSTOM CONTAINER_PACKAGES CIPLATFORM

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

for container in "$CONTAINER_DEFAULT" "$CONTAINER_CUSTOM" "$CONTAINER_PACKAGES"; do
    wait_for_ftl "$container"
done

# ---- Run BATS ---------------------------------------------------------------

echo "Running tests with BATS"

TEST_FILES=(
    test_suite.bats
)

# Configure BATS output and parallelization
BATS_FLAGS=("--print-output-on-failure");

# Use pretty output when stdout is a terminal; TAP format for CI
if [[ -t 1 ]]; then
    BATS_FLAGS+=("-p")
fi

# Parallelize tests if GNU parallel is available
if command -v parallel > /dev/null 2>&1; then
    echo "GNU parallel found, running tests in parallel"
    BATS_FLAGS+=("--jobs" "$(nproc)")
fi

"$BATS" "${BATS_FLAGS[@]}" "${TEST_FILES[@]}"
