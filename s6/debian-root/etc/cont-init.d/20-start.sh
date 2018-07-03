#!/usr/bin/with-contenv bash
set -e

bashCmd='bash -e'
if [ "${PH_VERBOSE:-0}" -gt 0 ] ; then 
    set -x ;
    bashCmd='bash -e -x'
fi

# Start dnsmasq for validate_env and gravity.sh
dnsmasq -7 /etc/dnsmasq.d

$bashCmd /start.sh
gravity.sh

# Kill dnsmasq because s6 won't like it if it's running when s6 services start
kill -9 $(pgrep dnsmasq) || true
