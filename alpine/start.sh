#!/bin/sh
if [ -z "$ServerIP" ] ; then
  echo "ERROR: To function correctly you must pass an environment variables of 'ServerIP' into the docker container with the IP of your docker host from which you are passing web (80) and dns (53) ports from"
  exit 1
fi;

# /tmp/piholeIP is the current override of auto-lookup in gravity.sh
echo "$ServerIP" > /etc/pihole/piholeIP;
echo "ipv4addr=$ServerIP" > /etc/pihole/setupVars.conf;
echo "piholeIPv6=$ServerIPv6" >> /etc/pihole/setupVars.conf;

if [ ! -f /var/run/dockerpihole-firstboot ] ; then
    echo "[www]" > $PHP_ENV_CONFIG;
    echo "env[PATH] = ${PATH}" >> $PHP_ENV_CONFIG;
    echo "env[PHP_ERROR_LOG] = ${PHP_ERROR_LOG}" >> $PHP_ENV_CONFIG;
    echo "env[ServerIP] = ${ServerIP}" >> $PHP_ENV_CONFIG;

    if [ -z "$VIRTUAL_HOST" ] ; then
      VIRTUAL_HOST="$ServerIP"
    fi;
    echo "env[VIRTUAL_HOST] = ${VIRTUAL_HOST}" >> $PHP_ENV_CONFIG;

    touch /var/run/dockerpihole-firstboot
else
    echo "Skipped first boot configuration, looks like you're restarting this container"
fi;

echo "Added ENV to php:"
cat $PHP_ENV_CONFIG

dnsType='default'
DNS1=${DNS1:-'8.8.8.8'}
DNS2=${DNS2:-'8.8.4.4'}
if [ "$DNS1" != '8.8.8.8' ] || [ "$DNS2" != '8.8.4.4' ] ; then
  dnsType='custom'
fi;

echo "Using $dnsType DNS servers: $DNS1 & $DNS2"
sed -i "s/@DNS1@/$DNS1/" /etc/dnsmasq.d/01-pihole.conf && \
sed -i "s/@DNS2@/$DNS2/" /etc/dnsmasq.d/01-pihole.conf && \

ip_versions="IPv4 and IPv6"
if [ "$IPv6" != "True" ] ; then
    ip_versions="IPv4"
    sed -i '/listen \[::\]:80;/ d' /etc/nginx/nginx.conf
fi;
echo "Using $ip_versions"

dnsmasq --test -7 /etc/dnsmasq.d || exit 1
php-fpm -t || exit 1
nginx -t || exit 1
echo " :: All config checks passed, starting ..."

if [ -n "$PYTEST" ] ; then sed -i 's/^gravity_spinup/#donotcurl/g' `which gravity.sh`; fi;
gravity.sh
dnsmasq -7 /etc/dnsmasq.d
php-fpm
nginx

tail -F /var/log/nginx/*.log /var/log/pihole.log
