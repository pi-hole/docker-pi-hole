#!/bin/bash
# This script contains function calls and lines that may rely on pihole-FTL to be running, it is run as part of a oneshot service on container startup

if [ "${PH_VERBOSE:-0}" -gt 0 ] ; then
    set -x ;
fi

gravityDBfile=$(pihole-FTL --config files.gravity)

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