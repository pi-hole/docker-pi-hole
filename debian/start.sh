#!/bin/bash -e
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
test_configs
test_framework_stubbing

gravity.sh # dnsmasq start included
service lighttpd start

tail -F /var/log/lighttpd/*.log /var/log/pihole.log
