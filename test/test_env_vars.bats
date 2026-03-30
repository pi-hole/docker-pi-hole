#!/usr/bin/env bats

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'helpers.sh'

setup_file() {
    CONTAINER=$(start_container \
        -e PIHOLE_UID=456 \
        -e PIHOLE_GID=456 \
        -e FTLCONF_webserver_api_password=1234567890 \
        -e FTLCONF_webserver_port=8080 \
        -e FTLCONF_dns_upstreams="8.8.8.8;1.1.1.1" \
        -e ADDITIONAL_PACKAGES=wget \
        -e TAIL_FTL_LOG=0)
    wait_for_log "$CONTAINER" "FTL log output is disabled"
    export CONTAINER
}

teardown_file() {
    docker rm -f "$CONTAINER" > /dev/null 2>&1 || true
}

# ---- FTL configuration ------------------------------------------------------

@test "FTLCONF_ variables successfully configure FTL" {
    run docker exec "$CONTAINER" pihole-FTL --config
    assert_success
    assert_output --partial "dns.upstreams = [ 8.8.8.8, 1.1.1.1 ]"
    assert_output --partial "webserver.port = 8080"
}

# ---- Container configuration ------------------------------------------------

@test "Custom PIHOLE_UID is applied to pihole user" {
    run docker exec "$CONTAINER" id -u pihole
    assert_success
    assert_output "456"
}

@test "Custom PIHOLE_GID is applied to pihole group" {
    run docker exec "$CONTAINER" id -g pihole
    assert_success
    assert_output "456"
}

# ---- Web password setup -----------------------------------------------------

@test "Password defined by environment variable is used" {
    run docker logs "$CONTAINER"
    assert_success
    assert_output --partial "Assigning password defined by Environment Variable"
}

# ---- Additional packages ----------------------------------------------------

@test "ADDITIONAL_PACKAGES are installed" {
    run docker exec "$CONTAINER" which wget
    assert_success
}

# ---- Web interface ----------------------------------------------------------

@test "Web interface is accessible on custom port" {
    run docker exec "$CONTAINER" curl -sf http://localhost:8080/admin
    assert_success
}

# ---- TAIL_FTL_LOG disabled --------------------------------------------------

@test "TAIL_FTL_LOG=0 suppresses FTL log output in docker logs" {
    # TAIL_FTL_LOG defaults to 1 (enabled); the default container exercises that path.
    # This test verifies the opt-out case.
    run docker logs "$CONTAINER"
    assert_success
    assert_output --partial "FTL log output is disabled"
    refute_output --partial "########## FTL started"
}
