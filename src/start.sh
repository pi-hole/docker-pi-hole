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

    # Warn about experimental builds
    if [ -f /pihole.docker.tag ] && grep -q "experimental" /pihole.docker.tag; then
        echo ""
        echo "  ⚠⚠⚠ WARNING ⚠⚠⚠"
        echo "  [!] This is an EXPERIMENTAL build of Pi-hole Docker"
        echo "  [!] This build may be unstable or contain breaking changes"
        echo "  [!] Use only if you have been asked to by the Pi-hole team"
        echo "  [!] Report any issues to: https://github.com/pi-hole/docker-pi-hole/issues"
        echo "  ⚠⚠⚠ WARNING ⚠⚠⚠"
        echo ""
        sleep 5
    fi

    # If the file /etc/pihole/setupVars.conf exists, but /etc/pihole/pihole.toml does not, then we are migrating v5->v6
    # FTL Will handle the migration of the config files
    if [[ -f /etc/pihole/setupVars.conf && ! -f /etc/pihole/pihole.toml ]]; then
        echo "  [i] v5 files detected that have not yet been migrated to v6"
        echo ""
        migrate_v5_configs
    fi

    # ===========================
    # Initial checks
    # ===========================

    # If PIHOLE_UID is set, modify the pihole user's id to match
    set_uid_gid

    # Configure FTL with any environment variables if needed
    echo "  [i] Starting FTL configuration"
    ftl_config

    # Install additional packages inside the container if requested
    install_additional_packages

    # Start crond for scheduled scripts (logrotate, pihole flush, gravity update etc)
    start_cron

    # Install the logrotate config file
    install_logrotate

    #migrate Gravity Database if needed:
    migrate_gravity

    echo "  [i] pihole-FTL pre-start checks"
    # Run the post stop script to cleanup any remaining artifacts from a previous run
    sh /opt/pihole/pihole-FTL-poststop.sh

    fix_capabilities
    sh /opt/pihole/pihole-FTL-prestart.sh

    # Get the FTL log file path from the config
    FTLlogFile=$(getFTLConfigValue files.log.ftl)

    # Get the EOF position of the FTL log file so that we can tail from there later.
    local startFrom
    startFrom=$(stat -c%s "${FTLlogFile}")

    echo "  [i] Starting pihole-FTL ($FTL_CMD) as ${DNSMASQ_USER}"
    echo ""

    capsh --user="${DNSMASQ_USER}" --keep=1 -- -c "/usr/bin/pihole-FTL $FTL_CMD >/dev/null" &
    # Notes on above:
    # - DNSMASQ_USER default of pihole is in Dockerfile & can be overwritten by runtime container env
    # - /var/log/pihole/pihole*.log has FTL's output that no-daemon would normally print in FG too
    #   prevent duplicating it in docker logs by sending to dev null

    # We need the PID of the capsh process so that we can wait for it to finish
    CAPSH_PID=$!

    # Wait for FTL to start by monitoring the FTL log file for the "FTL started" line
    if ! timeout 30 tail -F -c +$((startFrom + 1)) -- "${FTLlogFile}" | grep -q '########## FTL started'; then
        echo "  [!] ERROR: Did not find 'FTL started' message in ${FTLlogFile} in 30 seconds, stopping container"
        exit 1
    fi

    pihole updatechecker
    local versionsOutput
    versionsOutput=$(pihole -v)
    echo "  [i] Version info:"
    printf "%b" "${versionsOutput}\\n" | sed 's/^/      /'
    echo ""

    if [ "${TAIL_FTL_LOG:-1}" -eq 1 ]; then
        # Start tailing the FTL log file from the EOF position we recorded on container start
        tail -F -c +$((startFrom + 1)) -- "${FTLlogFile}" &
    else
        echo "  [i] FTL log output is disabled. Remove the Environment variable TAIL_FTL_LOG, or set it to 1 to enable FTL log output."
    fi

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
        echo "  [i] Container stop requested..."
        echo "  [i] pihole-FTL is running - Attempting to shut it down cleanly"
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

    echo ""
    echo "  [i] pihole-FTL exited with status $FTL_EXIT_CODE"
    echo ""
    echo "  [i] Container will now stop or restart depending on your restart policy"
    echo "      https://docs.docker.com/engine/containers/start-containers-automatically/#use-a-restart-policy"
    echo ""

    exit "${FTL_EXIT_CODE}"

}

start
