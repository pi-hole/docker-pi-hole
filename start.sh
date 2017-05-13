#!/bin/bash -e
# Dockerfile variables
export IMAGE
export ServerIP
export ServerIPv6
export PYTEST
export PHP_ENV_CONFIG
export PHP_ERROR_LOG 
export HOSTNAME
export WEBLOGDIR
export DNS1
export DNS2
export INTERFACE
export IPv6

. /bash_functions.sh

echo " ::: Starting docker specific setup for docker diginc/pi-hole"
validate_env
prepare_setup_vars
change_setting "IPV4_ADDRESS" "$ServerIP"
change_setting "IPV6_ADDRESS" "$ServerIPv6"
setup_web_password "$WEBPASSWORD"
setup_dnsmasq
setup_php_env
setup_dnsmasq_hostnames "$ServerIP" "$ServerIPv6" "$HOSTNAME"
setup_ipv4_ipv6
test_configs
test_framework_stubbing
echo "::: Docker start setup complete - beginning s6 services"

# s6's init takes care of running services now, no more main start services function
