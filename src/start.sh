#!/bin/bash

if [ ! -x /bin/sh ]; then
    echo "Executable test for /bin/sh failed. Your Docker version is too old to run Alpine 3.14+ and Pi-hole. You must upgrade Docker.";
    exit 1;
fi

if [ "${PH_VERBOSE:-0}" -gt 0 ]; then
    set -x
fi

trap stop TERM INT QUIT HUP ERR

CAPSH_PID=""
TRAP_TRIGGERED=0

start() {

    # The below functions are all contained in bash_functions.sh
    # shellcheck source=/dev/null
    . /usr/bin/bash_functions.sh

    # If the file /etc/pihole/setupVars.conf exists, but /etc/pihole/pihole.toml does not, then we are migrating v5->v6
    # FTL Will handle the migration of the config files
    if [[ -f /etc/pihole/setupVars.conf && ! -f /etc/pihole/pihole.toml ]]; then
        __log "INFO" "pihole-docker" "v5 files detected that have not yet been migrated to v6"
        migrate_v5_configs
    fi

    # ===========================
    # Initial checks
    # ===========================

    # If PIHOLE_UID is set, modify the pihole user's id to match
    set_uid_gid

    # Configure FTL with any environment variables if needed
    __log "INFO" "pihole-docker" "Starting FTL configuration"
    ftl_config

    # Install additional packages inside the container if requested
    install_additional_packages

    # Start crond for scheduled scripts (logrotate, pihole flush, gravity update etc)
    start_cron

    # Install the logrotate config file
    install_logrotate

    #migrate Gravity Database if needed:
    migrate_gravity

    __log "INFO" "pihole-docker" "pihole-FTL pre-start checks"
    # Run the post stop script to cleanup any remaining artifacts from a previous run
    sh /opt/pihole/pihole-FTL-poststop.sh

    fix_capabilities
    sh /opt/pihole/pihole-FTL-prestart.sh

    # Get the FTL log file path from the config
    FTLlogFile=$(getFTLConfigValue files.log.ftl)

    # Get the EOF position of the FTL log file so that we can tail from there later.
    local startFrom
    startFrom=$(stat -c%s "${FTLlogFile}")

    __log "INFO" "pihole-docker" "Starting pihole-FTL as user ${DNSMASQ_USER}"

    capsh --user="${DNSMASQ_USER}" --keep=1 -- -c "/usr/bin/pihole-FTL $FTL_CMD" &
    # Notes on above:
    # - DNSMASQ_USER default of pihole is in Dockerfile & can be overwritten by runtime container env
    # - "--log-json" already writes full structured JSON, we can capture it directly

    # We need the PID of the capsh process so that we can wait for it to finish
    CAPSH_PID=$!

    # Wait for FTL to start by monitoring the FTL log file for the "FTL started" line
    if ! timeout 30 tail -F -c +$((startFrom + 1)) -- "${FTLlogFile}" | grep -q '########## FTL started'; then
        __log "ERROR" "pihole-docker" "Did not find 'FTL started' message in ${FTLlogFile} in 30 seconds, stopping container"
        exit 1
    fi

    pihole updatechecker

    # Get version information from API endpoint
    local versionJson
    versionJson=$(pihole api info/version | jq -c '{
      core: .version.core.local | {version, branch, hash},
      web: .version.web.local | {version, branch, hash},
      ftl: .version.ftl.local | {version, branch, hash, date}
    }')
    __log "INFO" "pihole-docker" "$versionJson"

    # Wait for the capsh process (which spawned FTL) to finish
    wait $CAPSH_PID
    FTL_EXIT_CODE=$?

    # If we are here, then FTL has exited.
    # If the trap was triggered, then stop will have already been called
    if [ $TRAP_TRIGGERED -eq 0 ]; then
        # Pass the exit code through to the stop function
        stop $FTL_EXIT_CODE
    fi
}

stop() {
    local FTL_EXIT_CODE=$1

    # if we have nothing in FTL_EXIT_CODE, then have been called by the trap. Close FTL and wait for the CAPSH_PID to finish
    if [ -z "${FTL_EXIT_CODE}" ]; then
        TRAP_TRIGGERED=1
        echo ""
        __log "INFO" "pihole-docker" "Container stop requested..."
        __log "INFO" "pihole-docker" "pihole-FTL is running - Attempting to shut it down cleanly"
        echo ""
        killall --signal 15 pihole-FTL

        wait $CAPSH_PID
        FTL_EXIT_CODE=$?
    fi

    # Wait for a few seconds to allow the FTL log tail to catch up before exiting the container
    sleep 2

    # ensure the exit code is an integer, if not set it to 1
    if ! [[ "${FTL_EXIT_CODE}" =~ ^[0-9]+$ ]]; then
        FTL_EXIT_CODE=1
    fi

    sh /opt/pihole/pihole-FTL-poststop.sh

    __log "INFO" "pihole-docker" "pihole-FTL exited with status ${FTL_EXIT_CODE}"
    __log "INFO" "pihole-docker" "Container will now stop or restart depending on your restart policy - https://docs.docker.com/engine/containers/start-containers-automatically/#use-a-restart-policy"

    exit "${FTL_EXIT_CODE}"

}

start
