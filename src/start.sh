#!/bin/bash -e

if [ "${PH_VERBOSE:-0}" -gt 0 ] ; then
    set -x ;
fi


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






#!/usr/bin/env bash

if [ "${PH_VERBOSE:-0}" -gt 0 ] ; then
    set -x ;
fi

# Remove possible leftovers from previous pihole-FTL processes
rm -f /dev/shm/FTL-* 2> /dev/null
rm -f /run/pihole/FTL.sock

# install /dev/null files to ensure they exist (create if non-existing, preserve if existing)
mkdir -pm 0755 /run/pihole /var/log/pihole
[[ ! -f /run/pihole-FTL.pid ]] && install /dev/null /run/pihole-FTL.pid
[[ ! -f /var/log/pihole/FTL.log ]] && install /dev/null /var/log/pihole/FTL.log
[[ ! -f /var/log/pihole/pihole.log ]] && install /dev/null /var/log/pihole/pihole.log
[[ ! -f /etc/pihole/dhcp.leases ]] && install /dev/null /etc/pihole/dhcp.leases

# Ensure that permissions are set so that pihole-FTL can edit all necessary files
chown pihole:pihole /run/pihole-FTL.pid /var/log/pihole/FTL.log /var/log/pihole/pihole.log /etc/pihole/dhcp.leases /run/pihole /etc/pihole
chmod 0644 /run/pihole-FTL.pid /var/log/pihole/FTL.log /var/log/pihole/pihole.log /etc/pihole/dhcp.leases # /etc/pihole/pihole.toml

# Ensure that permissions are set so that pihole-FTL can edit the files. We ignore errors as the file may not (yet) exist
chmod -f 0644 /etc/pihole/macvendor.db || true
# Chown database files to the user FTL runs as. We ignore errors as the files may not (yet) exist
chown -f pihole:pihole /etc/pihole/pihole-FTL.db /etc/pihole/gravity.db /etc/pihole/macvendor.db || true
# Chown database file permissions so that the pihole group (web interface) can edit the file. We ignore errors as the files may not (yet) exist
chmod -f 0664 /etc/pihole/pihole-FTL.db || true

# Backward compatibility for user-scripts that still expect log files in /var/log instead of /var/log/pihole/
# Should be removed with Pi-hole v6.0
if [ ! -f /var/log/pihole.log ]; then
    ln -s /var/log/pihole/pihole.log /var/log/pihole.log
    chown -h pihole:pihole /var/log/pihole.log

fi
if [ ! -f /var/log/pihole-FTL.log ]; then
    ln -s /var/log/pihole/FTL.log /var/log/pihole-FTL.log
    chown -h pihole:pihole /var/log/pihole-FTL.log
fi

pihole -g

capsh --user=$DNSMASQ_USER --keep=1 -- -c "/usr/bin/pihole-FTL $FTL_CMD >/dev/null" &
tail -f /var/log/pihole-FTL.log

# Notes on above:
# - DNSMASQ_USER default of pihole is in Dockerfile & can be overwritten by runtime container env
# - /var/log/pihole/pihole*.log has FTL's output that no-daemon would normally print in FG too
#   prevent duplicating it in docker logs by sending to dev null
