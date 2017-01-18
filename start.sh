#!/bin/bash -ex
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
export IPv6
#export setupVars="${setupVars:-/etc/pihole/setupVars.conf}"

. /bash_functions.sh

echo " ::: Starting docker specific setup for docker diginc/pi-hole"
validate_env
change_setting "IPV4_ADDRESS" "$ServerIP"
change_setting "IPV6_ADDRESS" "$ServerIPv6"
setup_dnsmasq_dns "$DNS1" "$DNS2"
setup_php_env
setup_dnsmasq_hostnames "$ServerIP" "$ServerIPv6" "$HOSTNAME"
setup_ipv4_ipv6
test_configs
test_framework_stubbing

docker_main "$IMAGE"
