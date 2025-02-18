#!/bin/bash

if [ "${PH_VERBOSE:-0}" -gt 0 ]; then
  set -x
fi

trap stop TERM INT QUIT HUP ERR

CAPSH_PID=""
TRAP_TRIGGERED=0

start() {

  local v5_volume=0

  # The below functions are all contained in bash_functions.sh
  # shellcheck source=/dev/null
  . /usr/bin/bash_functions.sh

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
  # Remove possible leftovers from previous pihole-FTL processes
  rm -f /dev/shm/FTL-* 2>/dev/null
  rm -f /run/pihole/FTL.sock

  fix_capabilities
  sh /opt/pihole/pihole-FTL-prestart.sh

  echo "  [i] Starting pihole-FTL ($FTL_CMD) as ${DNSMASQ_USER}"
  echo ""

  capsh --user="${DNSMASQ_USER}" --keep=1 -- -c "/usr/bin/pihole-FTL $FTL_CMD >/dev/null" &
  # Notes on above:
  # - DNSMASQ_USER default of pihole is in Dockerfile & can be overwritten by runtime container env
  # - /var/log/pihole/pihole*.log has FTL's output that no-daemon would normally print in FG too
  #   prevent duplicating it in docker logs by sending to dev null

  # We need the PID of the capsh process so that we can wait for it to finish
  CAPSH_PID=$!

  # Wait until the log file exists before continuing
  while [ ! -f /var/log/pihole/FTL.log ]; do
    sleep 0.5
  done

  #  Wait until the FTL log contains the "FTL started" message before continuing
  while ! grep -q '########## FTL started' /var/log/pihole/FTL.log; do
    sleep 0.5
  done
  
  pihole updatechecker
  local versionsOutput
  versionsOutput=$(pihole -v)
  echo "  [i] Version info:"
  printf "%b" "${versionsOutput}\\n" | sed 's/^/      /' 
  echo ""

  if [ "${TAIL_FTL_LOG:-1}" -eq 1 ]; then
    # Start tailing the FTL log from the most recent "FTL Started" message
    # Get the line number
    startFrom=$(grep -n '########## FTL started' /var/log/pihole/FTL.log | tail -1 | cut -d: -f1)
    # Start the tail from the line number and background it
    tail --follow=name -n +"${startFrom}" /var/log/pihole/FTL.log &
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

  echo ""
  echo "  [i] pihole-FTL exited with status $FTL_EXIT_CODE"
  echo ""
  echo "  [i] Container will now stop or restart depending on your restart policy"
  echo "      https://docs.docker.com/engine/containers/start-containers-automatically/#use-a-restart-policy"
  echo ""

  # If we are running pytest, keep the container alive for a little longer
  # to allow the tests to complete
  if [[ ${PYTEST} ]]; then
    sleep 10
  fi

  exit "${FTL_EXIT_CODE}"

}

start
