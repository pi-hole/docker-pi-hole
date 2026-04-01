#!/usr/bin/env bats

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'helpers.sh'

setup_file() {
    # Create a temporary file to act as the Docker secret
    local secret_file
    secret_file=$(mktemp)
    echo -n "mysecretpassword" > "$secret_file"
    export SECRET_FILE="$secret_file"

    CONTAINER=$(start_container \
        -e WEBPASSWORD_FILE=pihole_password \
        -v "${secret_file}:/run/secrets/pihole_password:ro")
    wait_for_log "$CONTAINER" "########## FTL started"
    export CONTAINER
}

teardown_file() {
    docker rm -f "$CONTAINER" > /dev/null 2>&1 || true
    rm -f "$SECRET_FILE"
}

# ---- Docker secrets ---------------------------------------------------------

@test "WEBPASSWORD_FILE reads the web password from a Docker secret" {
    run docker logs "$CONTAINER"
    assert_success
    assert_output --partial "Setting FTLCONF_webserver_api_password from file"
}
