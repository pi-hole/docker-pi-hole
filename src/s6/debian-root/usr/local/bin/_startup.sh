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
# validate_env || exit 1
ensure_basic_configuration
apply_FTL_Configs_From_Env

# Web interface setup
# ===========================
load_web_password_secret
setup_web_password

# Misc Setup
# ===========================
setup_blocklists

# FTL setup
# ===========================

# setup_FTL_User
setup_FTL_query_logging

[ -f /.piholeFirstBoot ] && rm /.piholeFirstBoot

echo "  [i] Docker start setup complete"
echo ""


echo "  [i] pihole-FTL ($FTL_CMD) will be started as ${DNSMASQ_USER}"
echo ""
