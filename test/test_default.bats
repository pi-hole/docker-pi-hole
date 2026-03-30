#!/usr/bin/env bats

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'helpers.sh'

setup_file() {
    CONTAINER=$(start_container)
    wait_for_log "$CONTAINER" "########## FTL started"
    export CONTAINER
    # Force tests in this file to run sequentially since the shutdown test will destroy the container that other tests depend on
    export BATS_NO_PARALLELIZE_WITHIN_FILE=true
}

teardown_file() {
    docker rm -f "$CONTAINER" > /dev/null 2>&1 || true
}

# ---- FTL binary -------------------------------------------------------------

@test "FTL reports version" {
    run docker exec "$CONTAINER" pihole-FTL -vv
    assert_success
    assert_output --partial "Version:"
}

@test "FTL reports correct architecture" {
    [ -n "${CIPLATFORM:-}" ] || skip "CIPLATFORM not set, running locally"
    run docker exec "$CONTAINER" pihole-FTL -vv
    assert_success
    assert_output --partial "Architecture:"
    assert_output --partial "$CIPLATFORM"
}

# ---- Container configuration ------------------------------------------------

@test "Cron file is valid" {
    run docker exec "$CONTAINER" /usr/bin/crontab /crontab.txt
    assert_success
}

# ---- Web password setup -----------------------------------------------------

@test "Random password is assigned on fresh start" {
    run docker logs "$CONTAINER"
    assert_success
    assert_output --partial "assigning random password:"
}

# ---- FTL shutdown (DO THIS LAST!)---------------------------------------------

@test "FTL starts up and shuts down cleanly" {
    # Stop gracefully (SIGTERM), then capture logs before teardown_file removes it
    run docker stop "$CONTAINER"
    local logs
    logs=$(docker logs "$CONTAINER" 2>&1)

    run echo "$logs"
    assert_output --partial "INFO: ########## FTL terminated after"
    assert_output --partial "(code 0)"
}
