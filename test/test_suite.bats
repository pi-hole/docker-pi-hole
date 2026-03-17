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

# ---- Container configuration ------------------------------------------------

@test "Cron file is valid" {
    run docker exec "$CONTAINER_DEFAULT" bash -c \
        "/usr/bin/crontab /crontab.txt 2>&1; crond -d 8 -L /cron.log 2>&1; cat /cron.log"
    [[ "$output" != *"parse error"* ]]
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
