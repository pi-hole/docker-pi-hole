#!/usr/bin/with-contenv bash
set -e

bashCmd='bash -e'
if [ "${PH_VERBOSE:-0}" -gt 0 ] ; then
    set -x ;
    bashCmd='bash -e -x'
fi

# used to start dnsmasq here for gravity to use...now that conflicts port 53

$bashCmd /start.sh
# Gotta go fast, no time for gravity
if [ -n "$PYTEST" ]; then
    sed -i 's/^gravity_spinup$/#gravity_spinup # DISABLED FOR PYTEST/g' "$(which gravity.sh)"
fi
if [ -z "$SKIPGRAVITYONBOOT" ]; then
    echo '@reboot root PATH="$PATH:/usr/sbin:/usr/local/bin/" pihole updateGravity >/var/log/pihole_updateGravity.log || cat /var/log/pihole_updateGravity.log' > /etc/cron.d/gravity-on-boot
else
    echo "  Skipping Gravity Database Update."
    [ ! -e /etc/cron.d/gravity-on-boot ] || rm /etc/cron.d/gravity-on-boot &>/dev/null
fi

# Kill dnsmasq because s6 won't like it if it's running when s6 services start
piholeFtlPid=$(pgrep pihole-FTL)
if [ $? -eq 0 ]; then
    echo "Killing pihole-FTL process ($piholeFtlPid) in preparation for s6 service startup."
    kill -9 $piholeFtlPid
else
    echo "Process for pihole-FTL not found. Assuming it is already stopped and skipping kill command."
fi

pihole -v
