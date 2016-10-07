#!/bin/sh
. /common_start.sh
# Dockerfile variables
export IMAGE
export ServerIP
export ServerIPv6
export DNS1
export DNS2
export PYTEST
export PHP_ENV_CONFIG
export PHP_ERROR_LOG 

validate_env
setup_saved_variables
setup_php_env
setup_dnsmasq

# alpine unique currently
ip_versions="IPv4 and IPv6"
if [ "$IPv6" != "True" ] ; then
    ip_versions="IPv4"
    sed -i '/listen \[::\]:80;/ d' /etc/nginx/nginx.conf
fi;
echo "Using $ip_versions"

test_configs
test_framework_stubbing

gravity.sh
dnsmasq -7 /etc/dnsmasq.d
php-fpm
nginx

tail -F /var/log/nginx/*.log /var/log/pihole.log
