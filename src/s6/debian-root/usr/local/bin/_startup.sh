#!/bin/bash -e

if [ "${PH_VERBOSE:-0}" -gt 0 ] ; then
    set -x ;
fi

# The below functions are all contained in bash_functions.sh
# shellcheck source=/dev/null
. /usr/local/bin/bash_functions.sh

# shellcheck source=/dev/null
SKIP_INSTALL=true . /etc/.pihole/automated\ install/basic-install.sh

echo "  [i] Starting docker specific checks & setup for docker pihole/pihole"

# TODO:
#if [ ! -f /.piholeFirstBoot ] ; then
#    echo "   [i] Not first container startup so not running docker's setup, re-create container to run setup again"
#else
#    regular_setup_functions
#fi

# Initial checks
# ===========================
fix_capabilities
validate_env || exit 1
ensure_basic_configuration

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
setup_blocklists

# FTL setup
# ===========================
setup_FTL_upstream_DNS
[[ -n "${DHCP_ACTIVE}" && ${DHCP_ACTIVE} == "true" ]] && echo "Setting DHCP server" && setup_FTL_dhcp
apply_FTL_Configs_From_Env
setup_FTL_User
setup_FTL_Interface
setup_FTL_ListeningBehaviour
setup_FTL_CacheSize
setup_FTL_query_logging
setup_FTL_server || true
[ -n "${DNS_FQDN_REQUIRED}" ] && change_setting "DNS_FQDN_REQUIRED" "$DNS_FQDN_REQUIRED"
[ -n "${DNSSEC}" ] && change_setting "DNSSEC" "$DNSSEC"
[ -n "${DNS_BOGUS_PRIV}" ] && change_setting "DNS_BOGUS_PRIV" "$DNS_BOGUS_PRIV"
# The following must be called last! It will source setupVars.conf and override any env vars users pass in before they have been applied
setup_FTL_ProcessDNSSettings

test_configs

[ -f /.piholeFirstBoot ] && rm /.piholeFirstBoot

echo "  [i] Docker start setup complete"
echo ""


echo "  [i] pihole-FTL ($FTL_CMD) will be started as ${DNSMASQ_USER}"
echo ""
