#!/bin/sh


service lighttpd start
gravity.sh # dnsmasq start included

tail -f /var/log/lighttpd/*.log /var/log/pihole.log

