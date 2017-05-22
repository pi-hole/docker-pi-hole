#!/usr/bin/with-contenv bash

# Early DNS Startup for the gravity list process to use
dnsmasq -7 /etc/dnsmasq.d

/start.sh
gravity.sh

# Done with DNS, let s6 services start up properly configured dns now
killall -9 dnsmasq
