#!/usr/bin/with-contenv bash
set

bashCmd='bash -e'
if [ "${PH_VERBOSE:-0}" -gt 0 ] ; then 
    set -x ;
    bashCmd='bash -e -x'
fi

$bashCmd /start.sh

dnsmasq -7 /etc/dnsmasq.d
gravity.sh
kill -9 $(pgrep dnsmasq) || true
