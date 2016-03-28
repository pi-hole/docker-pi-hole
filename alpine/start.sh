#!/bin/sh
dnsmasq --test || exit 1
php-fpm -t || exit 1
nginx -t || exit 1

if [ -n "$piholeIP" ] ; then
  # /tmp/piholeIP is the current override of auto-lookup in gravity.sh
  echo "$piholeIP" > /tmp/piholeIP;
else
  echo "ERROR: It is required you pass an environment variables of 'piholeIP' with the IP of your docker host which you are passing 80/53 from"
  exit 1
fi;

gravity.sh # pi-hole version minus the service dnsmasq start
dnsmasq
php-fpm
nginx

tail -F /var/log/nginx/*.log /var/log/pihole.log
