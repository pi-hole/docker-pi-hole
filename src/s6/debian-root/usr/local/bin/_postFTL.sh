#!/bin/bash
# This script contains function calls and lines that may rely on pihole-FTL to be running, it is run as part of a oneshot service on container startup

if [ "${PH_VERBOSE:-0}" -gt 0 ] ; then
    set -x ;
fi

gravityDBfile="/etc/pihole/gravity.db"
config_file="/etc/pihole/pihole-FTL.conf"
# make a point to mention which config file we're checking, as breadcrumb to revisit if/when pihole-FTL.conf is succeeded by TOML
echo "  Checking if custom gravity.db is set in ${config_file}"
if [[ -f "${config_file}" ]]; then
    gravityDBfile="$(grep --color=never -Po "^GRAVITYDB=\K.*" "${config_file}" 2> /dev/null || echo "/etc/pihole/gravity.db")"
fi

if [ -z "$SKIPGRAVITYONBOOT" ] || [ ! -f "${gravityDBfile}" ]; then
    if [ -n "$SKIPGRAVITYONBOOT" ];then
        echo "  SKIPGRAVITYONBOOT is set, however ${gravityDBfile} does not exist (Likely due to a fresh volume). This is a required file for Pi-hole to operate."
        echo "  Ignoring SKIPGRAVITYONBOOT on this occaision."
    fi
    pihole -g
else
    echo "  Skipping Gravity Database Update."
fi

# Run update checker to check for newer container, and display version output
echo ""
pihole updatechecker
pihole -v

DOCKER_TAG=$(cat /pihole.docker.tag)
echo "  Container tag is: ${DOCKER_TAG}"
echo ""