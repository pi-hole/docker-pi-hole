#!/bin/sh
if [ -z "$ServerIP" ] ; then
  echo "ERROR: It is required you pass an environment variables of 'ServerIP' with the IP of your docker host which you are passing 80/53 from"
  exit 1
fi;

# /tmp/piholeIP is the current override of auto-lookup in gravity.sh
echo "$ServerIP" > /etc/pihole/piholeIP;
sed -i "/bin-environment/ a\\\t\t\t\"ServerIP\" => \"${ServerIP}\"," $PHP_ENV_CONFIG
sed -i "/bin-environment/ a\\\t\t\t\"PHP_ERROR_LOG\" => \"${PHP_ERROR_LOG}\"," $PHP_ENV_CONFIG

if [ -n "$VIRTUAL_HOST" ] ; then
  sed -i "/bin-environment/ a\\\t\t\t\"VIRTUAL_HOST\" => \"${VIRTUAL_HOST}\"," $PHP_ENV_CONFIG
fi;

echo "Added ENV to php:"
grep -E '(VIRTUAL_HOST|ServerIP)' $PHP_ENV_CONFIG

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
lighttpd -t -f /etc/lighttpd/lighttpd.conf || exit 1

gravity.sh # dnsmasq start included
service lighttpd start

tail -F /var/log/lighttpd/*.log /var/log/pihole.log
