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

# ---- Container services -----------------------------------------------------

@test "crond is running" {
    run docker exec "$CONTAINER" pgrep crond
    assert_success
}

@test "Logrotate config is installed" {
    run docker exec "$CONTAINER" test -f /etc/pihole/logrotate
    assert_success
}

# ---- Default configuration --------------------------------------------------

@test "Default DNS upstreams are applied when none are configured" {
    run docker exec "$CONTAINER" pihole-FTL --config -q dns.upstreams
    assert_success
    assert_output --partial "8.8.8.8"
    assert_output --partial "8.8.4.4"
}

# ---- Web interface ----------------------------------------------------------

@test "Web interface is accessible" {
    run docker exec "$CONTAINER" curl -sf /dev/null http://localhost/admin/
    assert_success
}

# ---- Docker image -----------------------------------------------------------

@test "/pihole.docker.tag is present" {
    run docker exec "$CONTAINER" test -f /pihole.docker.tag
    assert_success
}

@test "macvendor.db is present" {
    run docker exec "$CONTAINER" test -f /macvendor.db
    assert_success
}

@test "macvendor.db path is configured in FTL" {
    run docker exec "$CONTAINER" pihole-FTL --config -q files.macvendor
    assert_success
    assert_output "/macvendor.db"
}

# ---- Runtime ----------------------------------------------------------------

@test "FTL is running as the pihole user" {
    run docker exec "$CONTAINER" pgrep -u pihole pihole-FTL
    assert_success
}

@test "Capabilities are applied to pihole-FTL" {
    run docker exec "$CONTAINER" getcap /usr/bin/pihole-FTL
    assert_success
    assert_output --partial "cap_net_raw"
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
