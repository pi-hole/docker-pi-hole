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

# ---- Run BATS ---------------------------------------------------------------

echo "Running tests with BATS"

export CIPLATFORM

TEST_FILES=(
    test_default.bats
    test_env_vars.bats
    test_secrets.bats
)

# Configure BATS output and parallelization
BATS_FLAGS=();

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
