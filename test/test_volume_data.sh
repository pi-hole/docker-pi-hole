#!/bin/bash 
set -ex
# Trying something different from the python test, this is a big integration test in bash
# Tests multiple volume settings and how they are impacted by the complete startup scripts + restart/re-creation of container
# Maybe a bit easier to read the workflow/debug in bash than python for others? 
# This workflow is VERY similar to python's tests, but in bash so not object-oriented/pytest fixture based

# Debug can be added anywhere to check current state mid-test
RED='\033[0;31m'
NC='\033[0m' # No Color
if [ $(id -u) != 0 ] ; then
    sudo=sudo # do not need if root (in docker)
fi
debug() {
    $sudo grep -r . "$VOL_PH"
    $sudo grep -r . "$VOL_DM"
}
# Cleanup at the end, print debug on fail
cleanup() {
    retcode=$?
    { set +x; } 2>/dev/null
    if [ $retcode != 0 ] ; then
        printf "${RED}ERROR / FAILURE${NC} - printing all volume info"
        debug
    fi
    docker rm -f $CONTAINER
    $sudo rm -rf $VOLUMES
    exit $retcode
}
trap "cleanup" INT TERM EXIT


# VOLUME TESTS

# Given...
DEBIAN_VERSION="$(DEBIAN_VERSION:-stretch)"
IMAGE="${1:-pihole:v5.0-amd64}-${DEBIAN_VERSION}"   # Default is latest build test image (generic, non release/branch tag)
VOLUMES="$(mktemp -d)"                              # A fresh volume directory
VOL_PH="$VOLUMES/pihole"
VOL_DM="$VOLUMES/dnsmasq.d"
tty -s && TTY='-t' || TTY=''

echo "Testing $IMAGE with volumes base path $VOLUMES"

# When
# Running stock+empty volumes (no ports to avoid conflicts)
CONTAINER="$(
    docker run -d \
    -v "$VOL_PH:/etc/pihole/" \
    -v "$VOL_DM:/etc/dnsmasq.d/" \
    -v "/dev/null:/etc/pihole/adlists.list" \
    --entrypoint='' \
    $IMAGE \
    tail -f /dev/null
)"  # container backgrounded for multipiple operations over time

EXEC() { 
    local container="$1"
    # Must quote for complex commands
    docker exec $TTY $container bash -c "$2" 
}
EXEC $CONTAINER /start.sh  # run all the startup scripts
    
# Then default are present
grep "PIHOLE_DNS_1=8.8.8.8" "$VOL_PH/setupVars.conf"
grep "PIHOLE_DNS_2=8.8.4.4" "$VOL_PH/setupVars.conf"
grep "IPV4_ADDRESS=0.0.0.0" "$VOL_PH/setupVars.conf"
grep -E "WEBPASSWORD=.+" "$VOL_PH/setupVars.conf"

# Given the settings are manually changed (not good settings, just for testing changes)
EXEC $CONTAINER 'pihole -a setdns 127.1.1.1,127.2.2.2,127.3.3.3,127.4.4.4'
EXEC $CONTAINER '. /opt/pihole/webpage.sh ; change_setting IPV4_ADDRESS 10.0.0.0'
EXEC $CONTAINER 'pihole -a -p login'
assert_new_settings() {
    grep "PIHOLE_DNS_1=127.1.1.1" "$VOL_PH/setupVars.conf"
    grep "PIHOLE_DNS_2=127.2.2.2" "$VOL_PH/setupVars.conf"
    grep "PIHOLE_DNS_3=127.3.3.3" "$VOL_PH/setupVars.conf"
    grep "PIHOLE_DNS_4=127.4.4.4" "$VOL_PH/setupVars.conf"
    grep "IPV4_ADDRESS=10.0.0.0" "$VOL_PH/setupVars.conf"
    grep "WEBPASSWORD=6060d59351e8c2f48140f01b2c3f3b61652f396c53a5300ae239ebfbe7d5ff08" "$VOL_PH/setupVars.conf"
    grep "server=127.1.1.1" $VOL_DM/01-pihole.conf
    grep "server=127.2.2.2" $VOL_DM/01-pihole.conf
}
assert_new_settings

# When Restarting
docker restart $CONTAINER
# Then settings are still manual changed values
assert_new_settings

# When removing/re-creating the container
docker rm -f $CONTAINER
CONTAINER="$(
    docker run -d \
    -v "$VOL_PH:/etc/pihole/" \
    -v "$VOL_DM:/etc/dnsmasq.d/" \
    -v "/dev/null:/etc/pihole/adlists.list" \
    --entrypoint='' \
    $IMAGE \
    tail -f /dev/null
)"  # container backgrounded for multipiple operations over time

# Then settings are still manual changed values
assert_new_settings
