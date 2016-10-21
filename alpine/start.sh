#!/bin/sh
. /common_start.sh
# Dockerfile variables
export IMAGE
export ServerIP
export ServerIPv6
export PYTEST
export PHP_ENV_CONFIG
export PHP_ERROR_LOG 

validate_env
setup_saved_variables
setup_php_env
setup_dnsmasq "$DNS1" "$DNS2"
setup_ipv4_ipv6
test_configs
test_framework_stubbing

gravity.sh # dnsmasq start included
php-fpm
nginx

tail -F /var/log/nginx/*.log /var/log/pihole.log
