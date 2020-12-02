#!/bin/bash -e
# Dockerfile variables
export TAG
export ServerIP
export ServerIPv6
export PYTEST
export PHP_ENV_CONFIG
export PHP_ERROR_LOG
export HOSTNAME
export WEBLOGDIR
export DNS1
export DNS2
export DNSSEC
export DNS_BOGUS_PRIV
export DNS_FQDN_REQUIRED
export INTERFACE
export DNSMASQ_LISTENING_BEHAVIOUR="$DNSMASQ_LISTENING"
export IPv6
export WEB_PORT
export REV_SERVER
export REV_SERVER_DOMAIN
export REV_SERVER_TARGET
export REV_SERVER_CIDR
export CONDITIONAL_FORWARDING
export CONDITIONAL_FORWARDING_IP
export CONDITIONAL_FORWARDING_DOMAIN
export CONDITIONAL_FORWARDING_REVERSE
export TEMPERATUREUNIT
export ADMIN_EMAIL
export WEBUIBOXEDLAYOUT

export adlistFile='/etc/pihole/adlists.list'

# The below functions are all contained in bash_functions.sh
. /bash_functions.sh

# Ensure we have all functions available to update our configurations
. /opt/pihole/webpage.sh

# PH_TEST prevents the install from actually running (someone should rename that)
PH_TEST=true . $PIHOLE_INSTALL

echo " ::: Starting docker specific checks & setup for docker pihole/pihole"

# TODO:
#if [ ! -f /.piholeFirstBoot ] ; then
#    echo " ::: Not first container startup so not running docker's setup, re-create container to run setup again"
#else
#    regular_setup_functions
#fi

fix_capabilities
load_web_password_secret
generate_password
validate_env || exit 1
prepare_configs
change_setting "PIHOLE_INTERFACE" "$PIHOLE_INTERFACE"
change_setting "IPV4_ADDRESS" "$IPV4_ADDRESS"
change_setting "QUERY_LOGGING" "$QUERY_LOGGING"
change_setting "INSTALL_WEB_SERVER" "$INSTALL_WEB_SERVER"
change_setting "INSTALL_WEB_INTERFACE" "$INSTALL_WEB_INTERFACE"
change_setting "LIGHTTPD_ENABLED" "$LIGHTTPD_ENABLED"
change_setting "IPV4_ADDRESS" "$ServerIP"
change_setting "IPV6_ADDRESS" "$ServerIPv6"
change_setting "DNS_BOGUS_PRIV" "$DNS_BOGUS_PRIV"
change_setting "DNS_FQDN_REQUIRED" "$DNS_FQDN_REQUIRED"
change_setting "DNSSEC" "$DNSSEC"
change_setting "REV_SERVER" "$REV_SERVER"
change_setting "REV_SERVER_DOMAIN" "$REV_SERVER_DOMAIN"
change_setting "REV_SERVER_TARGET" "$REV_SERVER_TARGET"
change_setting "REV_SERVER_CIDR" "$REV_SERVER_CIDR"
if [ -z "$REV_SERVER" ];then
    # If the REV_SERVER* variables are set, then there is no need to add these.
    # If it is not set, then adding these variables is fine, and they will be converted by the Pi-hole install script
    change_setting "CONDITIONAL_FORWARDING" "$CONDITIONAL_FORWARDING"
    change_setting "CONDITIONAL_FORWARDING_IP" "$CONDITIONAL_FORWARDING_IP"
    change_setting "CONDITIONAL_FORWARDING_DOMAIN" "$CONDITIONAL_FORWARDING_DOMAIN"
    change_setting "CONDITIONAL_FORWARDING_REVERSE" "$CONDITIONAL_FORWARDING_REVERSE"
fi
setup_web_port "$WEB_PORT"
setup_web_password "$WEBPASSWORD"
setup_temp_unit "$TEMPERATUREUNIT"
setup_ui_layout "$WEBUIBOXEDLAYOUT"
setup_admin_email "$ADMIN_EMAIL"
setup_dnsmasq "$DNS1" "$DNS2" "$INTERFACE" "$DNSMASQ_LISTENING_BEHAVIOUR"
setup_php_env
setup_dnsmasq_hostnames "$ServerIP" "$ServerIPv6" "$HOSTNAME"
setup_ipv4_ipv6
setup_lighttpd_bind "$ServerIP"
setup_blocklists
test_configs

[ -f /.piholeFirstBoot ] && rm /.piholeFirstBoot

echo " ::: Docker start setup complete"
