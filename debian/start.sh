#!/bin/sh
dnsmasq --test || exit 1
lighttpd -t -f /etc/lighttpd/lighttpd.conf || exit 1

if [ -n "$piholeIP" ] ; then
  # /tmp/piholeIP is the current override of auto-lookup in gravity.sh
  echo "$piholeIP" > /tmp/piholeIP;
else
  echo "ERROR: It is required you pass an environment variables of 'piholeIP' with the IP of your docker host which you are passing 80/53 from"
  exit 1
fi;

gravity.sh # dnsmasq start included
service lighttpd start

tail -f /var/log/lighttpd/*.log /var/log/pihole.log
