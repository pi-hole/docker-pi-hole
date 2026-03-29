#!/usr/bin/env bats

# Containers are started by run.sh and their IDs exported as environment
# variables. All tests (except the shutdown test) share these containers,
# so each configuration is only booted once per test run.
#
# CONTAINER_DEFAULT   - no extra env vars
# CONTAINER_CUSTOM    - PIHOLE_UID=456, PIHOLE_GID=456, FTLCONF_webserver_api_password=1234567890

# ---- FTL binary -------------------------------------------------------------

@test "FTL reports version" {
    run docker exec "$CONTAINER_DEFAULT" pihole-FTL -vv
    [ "$status" -eq 0 ]
    [[ "$output" == *"Version:"* ]]
}

@test "FTL reports correct architecture" {
    [ -n "${CIPLATFORM:-}" ] || skip "CIPLATFORM not set, running locally"
    run docker exec "$CONTAINER_DEFAULT" pihole-FTL -vv
    [ "$status" -eq 0 ]
    [[ "$output" == *"Architecture:"* ]]
    [[ "$output" == *"$CIPLATFORM"* ]]
}

@test "FTL starts up and shuts down cleanly" {
    # This test needs its own container because it stops it
    local platform_args=()
    [ -n "${CIPLATFORM:-}" ] && platform_args=(--platform "$CIPLATFORM")

    local container
    container=$(docker run -d -t "${platform_args[@]}" -e TZ="Europe/London" pihole:test)

    # Wait for FTL to start
    local timeout=60
    local elapsed=0
    until docker logs "$container" 2>&1 | grep -q "########## FTL started"; do
        sleep 1
        elapsed=$(( elapsed + 1 ))
        if (( elapsed >= timeout )); then
            docker rm -f "$container"
            echo "FTL did not start within ${timeout}s"
            return 1
        fi
    done

    # Stop gracefully (SIGTERM), then capture logs before removing
    docker stop "$container"
    local logs
    logs=$(docker logs "$container" 2>&1)
    docker rm "$container"

    [[ "$logs" == *"INFO: ########## FTL terminated after"* ]]
    [[ "$logs" == *"(code 0)"* ]]
}

@test "FTLCONF_ variables successfully configure FTL" {
    run docker exec "$CONTAINER_CUSTOM" pihole-FTL --config
    [ "$status" -eq 0 ]
    [[ "$output" == *"dns.upstreams = [ 8.8.8.8, 1.1.1.1 ]"* ]]
    [[ "$output" == *"webserver.port = 8080"* ]]
}


# ---- Additional packages ----------------------------------------------------

@test "ADDITIONAL_PACKAGES are installed" {
    run docker exec "$CONTAINER_PACKAGES" which wget
    [ "$status" -eq 0 ]
}

# ---- Container configuration ------------------------------------------------

@test "Cron file is valid" {
    run docker exec "$CONTAINER_DEFAULT" /usr/bin/crontab /crontab.txt
    [ "$status" -eq 0 ]
}

@test "Custom PIHOLE_UID is applied to pihole user" {
    run docker exec "$CONTAINER_CUSTOM" id -u pihole
    [ "$status" -eq 0 ]
    [ "$output" = "456" ]
}

@test "Custom PIHOLE_GID is applied to pihole group" {
    run docker exec "$CONTAINER_CUSTOM" id -g pihole
    [ "$status" -eq 0 ]
    [ "$output" = "456" ]
}

# ---- Web password setup -----------------------------------------------------

@test "Random password is assigned on fresh start" {
    run docker logs "$CONTAINER_DEFAULT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"assigning random password:"* ]]
}

@test "Password defined by environment variable is used" {
    run docker exec "$CONTAINER_CUSTOM" bash -c ". bash_functions.sh; setup_web_password"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Assigning password defined by Environment Variable"* ]]
}

# ---- TAIL_FTL_LOG -----------------------------------------------------------

@test "TAIL_FTL_LOG=0 suppresses FTL log output in docker logs" {
    # TAIL_FTL_LOG defaults to 1 (enabled), so CONTAINER_DEFAULT already exercises
    # the enabled path. This test verifies the opt-out case: that setting it to 0
    # suppresses FTL log lines and emits the expected notice instead.
    local platform_args=()
    [ -n "${CIPLATFORM:-}" ] && platform_args=(--platform "$CIPLATFORM")

    local container
    container=$(docker run -d -t "${platform_args[@]}" \
        -e TZ="Europe/London" \
        -e TAIL_FTL_LOG=0 \
        pihole:test)

    # The "disabled" notice only appears after FTL has started, so waiting for it
    # confirms both that FTL started and that the suppression logic ran.
    local timeout=60
    local elapsed=0
    until docker logs "$container" 2>&1 | grep -q "FTL log output is disabled"; do
        sleep 1
        elapsed=$(( elapsed + 1 ))
        if (( elapsed >= timeout )); then
            docker rm -f "$container"
            echo "Container did not reach expected state within ${timeout}s"
            return 1
        fi
    done

    run docker logs "$container"
    docker rm -f "$container"

    [ "$status" -eq 0 ]
    [[ "$output" == *"FTL log output is disabled"* ]]
    [[ "$output" != *"########## FTL started"* ]]
}
