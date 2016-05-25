#!/bin/sh
if [ -n "$ServerIP" ] ; then
  # /tmp/piholeIP is the current override of auto-lookup in gravity.sh
  echo "$ServerIP" > /etc/pihole/piholeIP;
else
  echo "ERROR: To function correctly you must pass an environment variables of 'ServerIP' into the docker container with the IP of your docker host from which you are passing web (80) and dns (53) ports from"
  exit 1
fi;

dnsType='default'
DNS1=${DNS1:-'8.8.8.8'}
DNS2=${DNS2:-'8.8.4.4'}
if [ "$DNS1" != '8.8.8.8' ] || [ "$DNS2" != '8.8.4.4' ] ; then 
  dnsType='custom'
fi;

echo "Using $dnsType DNS servers: $DNS1 & $DNS2"
sed -i "s/@DNS1@/$DNS1/" /etc/dnsmasq.d/01-pihole.conf && \
sed -i "s/@DNS2@/$DNS2/" /etc/dnsmasq.d/01-pihole.conf && \

dnsmasq --test -7 /etc/dnsmasq.d || exit 1
php-fpm -t || exit 1
nginx -t || exit 1

gravity.sh
dnsmasq -7 /etc/dnsmasq.d
php-fpm
nginx

tail -F /var/log/nginx/*.log /var/log/pihole.log
