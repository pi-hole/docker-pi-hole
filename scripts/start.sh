#!/bin/bash -e

# If user has set QUERY_LOGGING Env Var, copy it out to _OVERRIDE,
# else it will get overridden when we source bash_functions.sh
# (which then sources basic-install.sh)
[ -n "${QUERY_LOGGING}" ] && export QUERY_LOGGING_OVERRIDE="${QUERY_LOGGING}"

# Legacy Env Vars preserved for backwards compatibility - convert them to FTLCONF_ equivalents
[ -n "${ServerIP}" ] && echo "ServerIP is deprecated. Converting to FTLCONF_REPLY_ADDR4" && export "FTLCONF_REPLY_ADDR4"="$ServerIP"
[ -n "${ServerIPv6}" ] && echo "ServerIPv6 is deprecated. Converting to FTLCONF_REPLY_ADDR6" && export "FTLCONF_REPLY_ADDR6"="$ServerIPv6"

# The below functions are all contained in bash_functions.sh
# shellcheck source=/dev/null
. /bash_functions.sh

# shellcheck source=/dev/null
SKIP_INSTALL=true . "${PIHOLE_INSTALL}"

echo " ::: Starting docker specific checks & setup for docker pihole/pihole"

# TODO:
#if [ ! -f /.piholeFirstBoot ] ; then
#    echo " ::: Not first container startup so not running docker's setup, re-create container to run setup again"
#else
#    regular_setup_functions
#fi

# Initial checks
# ===========================
fix_capabilities
validate_env || exit 1
ensure_basic_configuration

# FTL setup
# ===========================
setup_FTL_upstream_DNS
[[ -n "${DHCP_ACTIVE}" && ${DHCP_ACTIVE} == "true" ]] && echo "Setting DHCP server" && setup_FTL_dhcp
apply_FTL_Configs_From_Env
setup_FTL_User
setup_FTL_Interface
setup_FTL_CacheSize
setup_FTL_query_logging
setup_FTL_server || true
[ -n "${DNS_FQDN_REQUIRED}" ] && change_setting "DNS_FQDN_REQUIRED" "$DNS_FQDN_REQUIRED"
[ -n "${DNSSEC}" ] && change_setting "DNSSEC" "$DNSSEC"
[ -n "${DNS_BOGUS_PRIV}" ] && change_setting "DNS_BOGUS_PRIV" "$DNS_BOGUS_PRIV"
# We call the following function directly as it also allows us to run ProcessDNSSettings
# (to commit settings to 01-pihole.conf) without sourcing webpage.sh
# pihole -a -i "$DNSMASQ_LISTENING"

# Web interface setup
# ===========================
setup_web_port
load_web_password_secret
setup_web_password
setup_web_theme
setup_web_temp_unit
setup_web_layout
setup_web_php_env

# lighttpd setup
# ===========================
setup_ipv4_ipv6
setup_lighttpd_bind

# Misc Setup
# ===========================
setup_admin_email
setup_blocklists

test_configs

[ -f /.piholeFirstBoot ] && rm /.piholeFirstBoot

echo "::: Docker start setup complete"

pihole -v

echo "  Container tag is: ${PIHOLE_DOCKER_TAG}"
