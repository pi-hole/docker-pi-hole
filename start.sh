#!/bin/bash -e
. /bash_functions.sh
# Dockerfile variables
export IMAGE
export ServerIP
export ServerIPv6
export PYTEST
export PHP_ENV_CONFIG
export PHP_ERROR_LOG 
export HOSTNAME

validate_env
setup_saved_variables
setup_php_env
setup_dnsmasq_dns "$DNS1" "$DNS2"
setup_dnsmasq_hostnames "$ServerIP" "$ServerIPv6" "$HOSTNAME"
setup_ipv4_ipv6
test_configs
test_framework_stubbing

main "$IMAGE"
