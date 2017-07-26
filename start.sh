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
validate_env || exit 1
prepare_setup_vars
change_setting "IPV4_ADDRESS" "$ServerIP"
change_setting "IPV6_ADDRESS" "$ServerIPv6"
setup_web_password "$WEBPASSWORD"
setup_dnsmasq
setup_php_env
setup_dnsmasq_hostnames "$ServerIP" "$ServerIPv6" "$HOSTNAME"
setup_ipv4_ipv6
if [[ "$IMAGE" == 'debian' ]] ; then
	# if using '--net=host' only bing lighttpd on $ServerIP
	HOSTNET='grep "docker" /proc/net/dev/' #docker (docker0 by default) should only be present on the host system
	if [ -n "$HOSTNET" ] ; then
		if ! grep "server.bind" /etc/lighttpd/lighttpd.conf # if the declaration is already there, don't add it again
		then
			sed -i -E "s/server\.port\s+\=\s+80/server.bind\t\t = \"${ServerIP}\"\nserver.port\t\t = 80/" /etc/lighttpd/lighttpd.conf
		fi
	fi
fi

test_configs
test_framework_stubbing
echo "::: Docker start setup complete - beginning s6 services"

# s6's init takes care of running services now, no more main start services function
