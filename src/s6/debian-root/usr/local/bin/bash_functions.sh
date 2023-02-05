#!/bin/bash

# If user has set QUERY_LOGGING Env Var, copy it out to _OVERRIDE,
# else it will get overridden itself when we source basic-install.sh
[ -n "${QUERY_LOGGING}" ] && export QUERY_LOGGING_OVERRIDE="${QUERY_LOGGING}"

# Some of the bash_functions use utilities from Pi-hole's utils.sh
# shellcheck disable=SC2154
# shellcheck source=/dev/null
. /opt/pihole/utils.sh

export FTLconf="/etc/pihole/pihole-FTL.conf"
export dnsmasqconfig="/etc/dnsmasq.d/01-pihole.conf"
export adlistFile="/etc/pihole/adlists.list"

fix_capabilities() {
    # Testing on Docker 20.10.14 with no caps set shows the following caps available to the container:
    # Current: cap_chown,cap_dac_override,cap_fowner,cap_fsetid,cap_kill,cap_setgid,cap_setuid,cap_setpcap,cap_net_bind_service,cap_net_raw,cap_sys_chroot,cap_mknod,cap_audit_write,cap_setfcap=ep
    # FTL can also use CAP_NET_ADMIN and CAP_SYS_NICE. If we try to set them when they haven't been explicitly enabled, FTL will not start. Test for them first:
    echo "  [i] Setting capabilities on pihole-FTL where possible"
    /sbin/capsh --has-p=cap_chown 2>/dev/null && CAP_STR+=',CAP_CHOWN'
    /sbin/capsh --has-p=cap_net_bind_service 2>/dev/null && CAP_STR+=',CAP_NET_BIND_SERVICE'
    /sbin/capsh --has-p=cap_net_raw 2>/dev/null && CAP_STR+=',CAP_NET_RAW'
    /sbin/capsh --has-p=cap_net_admin 2>/dev/null && CAP_STR+=',CAP_NET_ADMIN' || DHCP_READY='false'
    /sbin/capsh --has-p=cap_sys_nice 2>/dev/null && CAP_STR+=',CAP_SYS_NICE'

    if [[ ${CAP_STR} ]]; then
        # We have the (some of) the above caps available to us - apply them to pihole-FTL
        echo "  [i] Applying the following caps to pihole-FTL:"
        IFS=',' read -ra CAPS <<< "${CAP_STR:1}"
        for i in "${CAPS[@]}"; do
            echo "        * ${i}"
        done

        setcap ${CAP_STR:1}+ep "$(which pihole-FTL)" || ret=$?

        if [[ $DHCP_READY == false ]] && [[ $FTLCONF_dhcp_active == true ]]; then
            # DHCP is requested but NET_ADMIN is not available.
            echo "ERROR: DHCP requested but NET_ADMIN is not available. DHCP will not be started."
            echo "      Please add cap_net_admin to the container's capabilities or disable DHCP."
            DHCP_ACTIVE='false'
            setFTLConfigValue dhcp.active false
        fi

        if [[ $ret -ne 0 && "${DNSMASQ_USER:-pihole}" != "root" ]]; then
            echo "  [!] ERROR: Unable to set capabilities for pihole-FTL. Cannot run as non-root."
            echo "            If you are seeing this error, please set the environment variable 'DNSMASQ_USER' to the value 'root'"
            exit 1
        fi
    else
        echo "  [!] WARNING: Unable to set capabilities for pihole-FTL."
        echo "              Please ensure that the container has the required capabilities."
        exit 1
    fi
}


# shellcheck disable=SC2034
ensure_basic_configuration() {
    echo "  [i] Ensuring basic configuration by re-running select functions from basic-install.sh"
    # TODO: Is this it?
    installLogrotate || true #installLogRotate can return 2 or 3, but we are still OK to continue in that case

    set +e
    mkdir -p /var/run/pihole /var/log/pihole
    touch /var/log/pihole/FTL.log /var/log/pihole/pihole.log

    # In case of `pihole` UID being changed, re-chown the pihole scripts and pihole command
    chown -R pihole:root "${PI_HOLE_INSTALL_DIR}"
    chown pihole:root "${PI_HOLE_BIN_DIR}/pihole"
    chown -R pihole:pihole /etc/pihole

    set -e

    # If FTLCONF_files_macvendor is not set
    if [[ -z "${FTLCONF_files_macvendor:-}" ]]; then
        # User is not passing in a custom location - so force FTL to use the file we moved to / during the build
        setFTLConfigValue "files.macvendor" "/macvendor.db"
    fi

    # setup_or_skip_gravity
}

setup_FTL_User(){
    # Run DNSMASQ as root user to avoid SHM permission issues
    if grep -r -q '^\s*user=' /etc/dnsmasq.* ; then
        # Change user that had been set previously to root
        for f in $(grep -r -l '^\s*user=' /etc/dnsmasq.*); do
            sed -i "/^\s*user=/ c\user=${DNSMASQ_USER}" "${f}"
        done
    else
      echo -e "\nuser=${DNSMASQ_USER}" >> /etc/dnsmasq.conf
    fi
}

apply_FTL_Configs_From_Env(){
    # Get all exported environment variables starting with FTLCONF_ as a prefix and call the setFTLConfigValue
    # function with the environment variable's suffix as the key. This allows applying any pihole-FTL.conf
    # setting defined here: https://docs.pi-hole.net/ftldns/configfile/
    echo ""
    echo "==========Applying settings from environment variables=========="
    source /opt/pihole/COL_TABLE
    declare -px | grep FTLCONF_ | sed -E 's/declare -x FTLCONF_([^=]+)=\"(|.+)\"/\1 \2/' | while read -r name value
    do
        # Replace underscores wi1th dots in the name to match pihole-FTL expectiations
        name="${name//_/.}"

        # Special handing for the value if the name is dns.upstreams
        if [ "$name" == "dns.upstreams" ]; then
            value="[\"${value//;/\",\"}\"]"
        fi

        if [ "$name" == "dns.reply.host.overwrite.v4" ]; then
            name="dns.reply.host.overwrite_v4"
        fi

        if $(setFTLConfigValue "${name}" "${value}" 2>&1); then
            echo "  ${TICK} Applied pihole-FTL setting $name=$value"
        else
            echo "  ${CROSS} Error Applying pihole-FTL setting $name=$value"
        fi


    done
    echo "================================================================"
    echo ""
}

setup_FTL_query_logging(){
    if [ "${QUERY_LOGGING_OVERRIDE}" == "false" ]; then
        echo "  [i] Disabling Query Logging"
        setFTLConfigValue dns.queryLogging "${QUERY_LOGGING_OVERRIDE}"
    else
        # If it is anything other than false, set it to true
        echo "  [i] Enabling Query Logging"
        setFTLConfigValue dns.queryLogging true
    fi

}

# setup_FTL_ProcessDNSSettings(){
#     # Commit settings to 01-pihole.conf

#     # shellcheck source=/dev/null
#     #. /opt/pihole/webpage.sh
#    # ProcessDNSSettings
# }


load_web_password_secret() {
   # If WEBPASSWORD is not set at all, attempt to read password from WEBPASSWORD_FILE,
   # allowing secrets to be passed via docker secrets
   if [ -z "${WEBPASSWORD+x}" ] && [ -n "${WEBPASSWORD_FILE}" ] && [ -r "${WEBPASSWORD_FILE}" ]; then
     WEBPASSWORD=$(<"${WEBPASSWORD_FILE}")
   fi;
}

setup_web_password() {
    if [ -z "${WEBPASSWORD+x}" ] ; then
        # ENV WEBPASSWORD_OVERRIDE is not set

        # Exit if password is already set (TODO: Revisit this. Maybe make setting password in environment variable mandatory?)
        if [[ $(pihole-FTL --config webserver.api.pwhash) != '""' ]]; then
            return
        fi
        # Generate new random password
        WEBPASSWORD=$(tr -dc _A-Z-a-z-0-9 < /dev/urandom | head -c 8)
        echo "  [i] Assigning random password: $WEBPASSWORD"
    else
        # ENV WEBPASSWORD_OVERRIDE is set and will be used
        echo "  [i] Assigning password defined by Environment Variable"
        # WEBPASSWORD="$WEBPASSWORD"
    fi

    # Explicitly turn off bash printing when working with secrets
    { set +x; } 2>/dev/null

    if [[ "$WEBPASSWORD" == "" ]] ; then
        echo "" | pihole -a -p
    else
        pihole -a -p "$WEBPASSWORD" "$WEBPASSWORD"
    fi

    # To avoid printing this if conditional in bash debug, turn off  debug above..
    # then re-enable debug if necessary (more code but cleaner printed output)
    if [ "${PH_VERBOSE:-0}" -gt 0 ] ; then
        set -x
    fi
}

setup_blocklists() {
    # Exit/return early without setting up adlists with defaults for any of the following conditions:
    # 1. skip_setup_blocklists env is set
    exit_string="(exiting ${FUNCNAME[0]} early)"

    if [ -n "${skip_setup_blocklists}" ]; then
        echo "  [i] skip_setup_blocklists requested $exit_string"
        return
    fi

    # 2. The adlist file exists already (restarted container or volume mounted list)
    if [ -f "${adlistFile}" ]; then
        echo "  [i] Preexisting ad list ${adlistFile} detected $exit_string"
        return
    fi

    echo "  [i] ${FUNCNAME[0]} now setting default blocklists up: "
    echo "  [i] TIP: Use a docker volume for ${adlistFile} if you want to customize for first boot"
    installDefaultBlocklists

    echo "  [i] Blocklists (${adlistFile}) now set to:"
    cat "${adlistFile}"
}
