#!/bin/bash -e

if [ "${PH_VERBOSE:-0}" -gt 0 ]; then
  set -x
fi

trap stop TERM INT QUIT HUP ERR

start() {

  # The below functions are all contained in bash_functions.sh
  # shellcheck source=/dev/null
  . /usr/bin/bash_functions.sh

  # shellcheck source=/dev/null
  # SKIP_INSTALL=true . /etc/.pihole/automated\ install/basic-install.sh

  echo "  [i] Starting docker specific checks & setup for docker pihole/pihole"

  # TODO:
  #if [ ! -f /.piholeFirstBoot ] ; then
  #    echo "   [i] Not first container startup so not running docker's setup, re-create container to run setup again"
  #else
  #    regular_setup_functions
  #fi

  # Initial checks
  # ===========================

  # If PIHOLE_UID is set, modify the pihole user's id to match
  if [ -n "${PIHOLE_UID}" ]; then
    currentId=$(id -u pihole)
    if [[ ${currentId} -ne ${PIHOLE_UID} ]]; then
      echo "  [i] Changing ID for user: pihole (${currentId} => ${PIHOLE_UID})"
      usermod -o -u ${PIHOLE_UID} pihole
    else
      echo "  [i] ID for user pihole is already ${PIHOLE_UID}, no need to change"
    fi
  fi

  # If PIHOLE_GID is set, modify the pihole group's id to match
  if [ -n "${PIHOLE_GID}" ]; then
    currentId=$(id -g pihole)
    if [[ ${currentId} -ne ${PIHOLE_GID} ]]; then
      echo "  [i] Changing ID for group: pihole (${currentId} => ${PIHOLE_GID})"
      groupmod -o -g ${PIHOLE_GID} pihole
    else
      echo "  [i] ID for group pihole is already ${PIHOLE_GID}, no need to change"
    fi
  fi

  fix_capabilities
  # validate_env || exit 1
  ensure_basic_configuration

  apply_FTL_Configs_From_Env

  # Web interface setup
  # ===========================
  # load_web_password_secret
  # setup_web_password

  # Misc Setup
  # ===========================
  # setup_blocklists

  # FTL setup
  # ===========================

  # setup_FTL_User
  # setup_FTL_query_logging

  [ -f /.piholeFirstBoot ] && rm /.piholeFirstBoot

  echo "  [i] Docker start setup complete"
  echo ""

  echo "  [i] pihole-FTL ($FTL_CMD) will be started as ${DNSMASQ_USER}"
  echo ""

  # Install editors inside container if requested
  if [ "${INSTALL_DEV_TOOLS:-0}" -gt 0 ]; then
    apk add --no-cache nano less
  fi

  # Remove possible leftovers from previous pihole-FTL processes
  rm -f /dev/shm/FTL-* 2>/dev/null
  rm -f /run/pihole/FTL.sock

  # Start crond for scheduled scripts (logrotate, pihole flush, gravity update etc)
  # crond

  # Randomize gravity update time
  sed -i "s/59 1 /$((1 + RANDOM % 58)) $((3 + RANDOM % 2))/" /crontab.txt
  # Randomize update checker time
  sed -i "s/59 17/$((1 + RANDOM % 58)) $((12 + RANDOM % 8))/" /crontab.txt
  /usr/bin/crontab /crontab.txt

  /usr/sbin/crond

#migrate Database if needed:
  gravityDBfile=$(getFTLConfigValue files.gravity)
  if [ -n "${SKIPGRAVITYONBOOT}" ]; then
    if [ -f "${gravityDBfile}" ]; then
      #skip set + file =>update if needed
      echo "  Skipping Gravity Database Update."
      # TODO: Revist this path if we move to a multistage build
      source /etc/.pihole/advanced/Scripts/database_migration/gravity-db.sh
      upgrade_gravityDB "${gravityDBfile}" "/etc/pihole"
    else
      #skip set + nofile => pihole -g (install error)
      echo "  SKIPGRAVITYONBOOT is set, however ${gravityDBfile} does not exist (Likely due to a fresh volume). This is a required file for Pi-hole to operate."
      echo "  Ignoring SKIPGRAVITYONBOOT on this occasion."
      pihole -g
    fi
    else
        echo "  Skipping Gravity Database Update."
    fi

  pihole updatechecker

  # Start pihole-FTL

  sh /opt/pihole/pihole-FTL-prestart.sh
  capsh --user=$DNSMASQ_USER --keep=1 -- -c "/usr/bin/pihole-FTL $FTL_CMD >/dev/null" &

  tail -f /var/log/pihole-FTL.log &

  # https://stackoverflow.com/a/49511035
  wait $!
  # Notes on above:
  # - DNSMASQ_USER default of pihole is in Dockerfile & can be overwritten by runtime container env
  # - /var/log/pihole/pihole*.log has FTL's output that no-daemon would normally print in FG too
  #   prevent duplicating it in docker logs by sending to dev null

}

stop() {
  # Ensure pihole-FTL shuts down cleanly on SIGTERM/SIGINT
  ftl_pid=$(pgrep pihole-FTL)
  killall --signal 15 pihole-FTL

  # Wait for pihole-FTL to exit
  while test -d /proc/"${ftl_pid}"; do
    sleep 0.5
  done

  exit
}

start
