#!/bin/sh
dnsmasq --test || exit 1
lighttpd -t -f /etc/lighttpd/lighttpd.conf || exit 1

gravity.sh # dnsmasq start included
service lighttpd start

tail -f /var/log/lighttpd/*.log /var/log/pihole.log
