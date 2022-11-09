#!/bin/bash

# If user has set QUERY_LOGGING Env Var, copy it out to _OVERRIDE,
# else it will get overridden itself when we source basic-install.sh
[ -n "${QUERY_LOGGING}" ] && export QUERY_LOGGING_OVERRIDE="${QUERY_LOGGING}"

# Legacy Env Vars preserved for backwards compatibility - convert them to FTLCONF_ equivalents
[ -n "${ServerIP}" ] && echo "ServerIP is deprecated. Converting to FTLCONF_LOCAL_IPV4" && export "FTLCONF_LOCAL_IPV4"="$ServerIP"
[ -n "${ServerIPv6}" ] && echo "ServerIPv6 is deprecated. Converting to FTLCONF_LOCAL_IPV6" && export "FTLCONF_LOCAL_IPV6"="$ServerIPv6"

# Previously used FTLCONF_ equivalent has since been deprecated, also convert this one
[ -n "${FTLCONF_REPLY_ADDR4}" ] && echo "FTLCONF_REPLY_ADDR4 is deprecated. Converting to FTLCONF_LOCAL_IPV4" && export "FTLCONF_LOCAL_IPV4"="$FTLCONF_REPLY_ADDR4"
[ -n "${FTLCONF_REPLY_ADDR6}" ] && echo "FTLCONF_REPLY_ADDR6 is deprecated. Converting to FTLCONF_LOCAL_IPV6" && export "FTLCONF_LOCAL_IPV6"="$FTLCONF_REPLY_ADDR6"

# Some of the bash_functions use utilities from Pi-hole's utils.sh
# shellcheck disable=SC2154
# shellcheck source=/dev/null
. /opt/pihole/utils.sh

export setupVars="/etc/pihole/setupVars.conf"
export FTLconf="/etc/pihole/pihole-FTL.conf"
export dnsmasqconfig="/etc/dnsmasq.d/01-pihole.conf"
export adlistFile="/etc/pihole/adlists.list"

change_setting() {
    addOrEditKeyValPair "${setupVars}" "${1}" "${2}"
}

changeFTLsetting() {
    addOrEditKeyValPair "${FTLconf}" "${1}" "${2}"
}

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

        if [[ $DHCP_READY == false ]] && [[ $DHCP_ACTIVE == true ]]; then
            # DHCP is requested but NET_ADMIN is not available.
            echo "ERROR: DHCP requested but NET_ADMIN is not available. DHCP will not be started."
            echo "      Please add cap_net_admin to the container's capabilities or disable DHCP."
            DHCP_ACTIVE='false'
            change_setting "DHCP_ACTIVE" "false"
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
    # Set Debian webserver variables for installConfigs
    LIGHTTPD_USER="www-data"
    LIGHTTPD_GROUP="www-data"
    LIGHTTPD_CFG="lighttpd.conf.debian"
    installConfigs
    installLogrotate || true #installLogRotate can return 2 or 3, but we are still OK to continue in that case

    if [ ! -f "${setupVars}" ]; then
        install -m 644 /dev/null "${setupVars}"
        echo "  [i] Creating empty ${setupVars} file."
        # The following setting needs to exist else the web interface version won't show in pihole -v
        change_setting "INSTALL_WEB_INTERFACE" "true"
    fi

    set +e
    mkdir -p /var/run/pihole /var/log/pihole
    touch /var/log/pihole/FTL.log /var/log/pihole/pihole.log

    chown pihole:root /etc/lighttpd

    # In case of `pihole` UID being changed, re-chown the pihole scripts and pihole command
    chown -R pihole:root "${PI_HOLE_INSTALL_DIR}"
    chown pihole:root "${PI_HOLE_BIN_DIR}/pihole"

    set -e
    # Re-write all of the setupVars to ensure required ones are present (like QUERY_LOGGING)

    # If the setup variable file exists,
    if [[ -e "${setupVars}" ]]; then
        cp -f "${setupVars}" "${setupVars}.update.bak"
    fi

    # Remove any existing macvendor.db and replace it with a symblink to the one moved to the root directory (see install.sh)
    if [[ -f "/etc/pihole/macvendor.db" ]]; then
        rm /etc/pihole/macvendor.db
    fi
    ln -s /macvendor.db /etc/pihole/macvendor.db

    # When fresh empty directory volumes are used then we need to create this file
    if [ ! -f /etc/dnsmasq.d/01-pihole.conf ] ; then
        cp /etc/.pihole/advanced/01-pihole.conf /etc/dnsmasq.d/
    fi;

    # setup_or_skip_gravity
}

validate_env() {
    # Optional FTLCONF_LOCAL_IPV4 is a valid IP
    # nc won't throw any text based errors when it times out connecting to a valid IP, otherwise it complains about the DNS name being garbage
    # if nc doesn't behave as we expect on a valid IP the routing table should be able to look it up and return a 0 retcode
    if [[ "$(nc -4 -w1 -z "$FTLCONF_LOCAL_IPV4" 53 2>&1)" != "" ]] && ! ip route get "$FTLCONF_LOCAL_IPV4" > /dev/null ; then
        echo "ERROR: FTLCONF_LOCAL_IPV4 Environment variable ($FTLCONF_LOCAL_IPV4) doesn't appear to be a valid IPv4 address"
        exit 1
    fi

    # Optional IPv6 is a valid address
    if [[ -n "$FTLCONF_LOCAL_IPV6" ]] ; then
        if [[ "$FTLCONF_LOCAL_IPV6" == 'kernel' ]] ; then
            echo "  [!] ERROR: You passed in IPv6 with a value of 'kernel', this maybe because you do not have IPv6 enabled on your network"
            unset FTLCONF_LOCAL_IPV6
            exit 1
        fi
        if [[ "$(nc -6 -w1 -z "$FTLCONF_LOCAL_IPV6" 53 2>&1)" != "" ]] && ! ip route get "$FTLCONF_LOCAL_IPV6" > /dev/null ; then
            echo "  [!] ERROR: FTLCONF_LOCAL_IPV6 Environment variable ($FTLCONF_LOCAL_IPV6) doesn't appear to be a valid IPv6 address"
            echo "        TIP: If your server is not IPv6 enabled just remove '-e FTLCONF_LOCAL_IPV6' from your docker container"
            exit 1
        fi
    fi;
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

setup_FTL_Interface(){
    local interface="${INTERFACE:-eth0}"

    # Set the interface for FTL to listen on
    local interfaceType='default'
    if [ "$interface" != 'eth0' ] ; then
      interfaceType='custom'
    fi;
    echo "  [i] FTL binding to $interfaceType interface: $interface"
    change_setting "PIHOLE_INTERFACE" "${interface}"
}

setup_FTL_ListeningBehaviour(){
    if [ -n "$DNSMASQ_LISTENING" ]; then
      change_setting "DNSMASQ_LISTENING" "${DNSMASQ_LISTENING}"
    fi;
}

setup_FTL_CacheSize() {
    local warning="  [i] WARNING: CUSTOM_CACHE_SIZE not used"
    local dnsmasq_pihole_01_location="/etc/dnsmasq.d/01-pihole.conf"
    # Quietly exit early for empty or default
    if [[ -z "${CUSTOM_CACHE_SIZE}" || "${CUSTOM_CACHE_SIZE}" == '10000' ]] ; then return ; fi

    if [[ "${DNSSEC}" == "true" ]] ; then
        echo "$warning - Cannot change cache size if DNSSEC is enabled"
        return
    fi

    if ! echo "$CUSTOM_CACHE_SIZE" | grep -q '^[0-9]*$' ; then
        echo "$warning - $CUSTOM_CACHE_SIZE is not an integer"
        return
    fi

    local -i custom_cache_size="$CUSTOM_CACHE_SIZE"
    if (( custom_cache_size < 0 )); then
        echo "$warning - $custom_cache_size is not a positive integer or zero"
        return
    fi
    echo "  [i] Custom CUSTOM_CACHE_SIZE set to $custom_cache_size"

    change_setting "CACHE_SIZE" "$custom_cache_size"
    sed -i "s/^cache-size=\s*[0-9]*/cache-size=$custom_cache_size/" ${dnsmasq_pihole_01_location}
}

apply_FTL_Configs_From_Env(){
    # Get all exported environment variables starting with FTLCONF_ as a prefix and call the changeFTLsetting
    # function with the environment variable's suffix as the key. This allows applying any pihole-FTL.conf
    # setting defined here: https://docs.pi-hole.net/ftldns/configfile/
    declare -px | grep FTLCONF_ | sed -E 's/declare -x FTLCONF_([^=]+)=\"(.+)\"/\1 \2/' | while read -r name value
    do
        echo "  [i] Applying pihole-FTL.conf setting $name=$value"
        changeFTLsetting "$name" "$value"
    done
}

setup_FTL_dhcp() {
  if [ -z "${DHCP_START}" ] || [ -z "${DHCP_END}" ] || [ -z "${DHCP_ROUTER}" ]; then
    echo "  [!] ERROR: Won't enable DHCP server because mandatory Environment variables are missing: DHCP_START, DHCP_END and/or DHCP_ROUTER"
    change_setting "DHCP_ACTIVE" "false"
  else
    change_setting "DHCP_ACTIVE" "${DHCP_ACTIVE}"
    change_setting "DHCP_START" "${DHCP_START}"
    change_setting "DHCP_END" "${DHCP_END}"
    change_setting "DHCP_ROUTER" "${DHCP_ROUTER}"
    change_setting "DHCP_LEASETIME" "${DHCP_LEASETIME}"
    change_setting "PIHOLE_DOMAIN" "${PIHOLE_DOMAIN}"
    change_setting "DHCP_IPv6" "${DHCP_IPv6}"
    change_setting "DHCP_rapid_commit" "${DHCP_rapid_commit}"
  fi
}

setup_FTL_query_logging(){
    if [ "${QUERY_LOGGING_OVERRIDE}" == "false" ]; then
        echo "  [i] Disabling Query Logging"
        change_setting "QUERY_LOGGING" "$QUERY_LOGGING_OVERRIDE"
        removeKey "${dnsmasqconfig}" log-queries
    else
        # If it is anything other than false, set it to true
        change_setting "QUERY_LOGGING" "true"
        # Set pihole logging on for good measure
        echo "  [i] Enabling Query Logging"
        addKey "${dnsmasqconfig}" log-queries
    fi

}

setup_FTL_server(){
    [ -n "${REV_SERVER}" ] && change_setting "REV_SERVER" "$REV_SERVER"
    [ -n "${REV_SERVER_DOMAIN}" ] && change_setting "REV_SERVER_DOMAIN" "$REV_SERVER_DOMAIN"
    [ -n "${REV_SERVER_TARGET}" ] && change_setting "REV_SERVER_TARGET" "$REV_SERVER_TARGET"
    [ -n "${REV_SERVER_CIDR}" ] && change_setting "REV_SERVER_CIDR" "$REV_SERVER_CIDR"

    if [ -z "$REV_SERVER" ];then
        # If the REV_SERVER* variables are set, then there is no need to add these.
        # If it is not set, then adding these variables is fine, and they will be converted by the Pi-hole install script
        [ -n "${CONDITIONAL_FORWARDING}" ] && change_setting "CONDITIONAL_FORWARDING" "$CONDITIONAL_FORWARDING"
        [ -n "${CONDITIONAL_FORWARDING_IP}" ] && change_setting "CONDITIONAL_FORWARDING_IP" "$CONDITIONAL_FORWARDING_IP"
        [ -n "${CONDITIONAL_FORWARDING_DOMAIN}" ] && change_setting "CONDITIONAL_FORWARDING_DOMAIN" "$CONDITIONAL_FORWARDING_DOMAIN"
        [ -n "${CONDITIONAL_FORWARDING_REVERSE}" ] && change_setting "CONDITIONAL_FORWARDING_REVERSE" "$CONDITIONAL_FORWARDING_REVERSE"
    fi
}

setup_FTL_upstream_DNS(){
    if [ -z "${PIHOLE_DNS_}" ]; then
        # For backward compatibility, if DNS1 and/or DNS2 are set, but PIHOLE_DNS_ is not, convert them to
        # a semi-colon delimited string and store in PIHOLE_DNS_
        # They are not used anywhere if PIHOLE_DNS_ is set already
        [ -n "${DNS1}" ] && echo "  [i] Converting DNS1 to PIHOLE_DNS_" && PIHOLE_DNS_="$DNS1"
        [[ -n "${DNS2}" && "${DNS2}" != "no" ]] && echo "  [i] Converting DNS2 to PIHOLE_DNS_" && PIHOLE_DNS_="$PIHOLE_DNS_;$DNS2"
    fi

    # Parse the PIHOLE_DNS variable, if it exists, and apply upstream servers to Pi-hole config
    if [ -n "${PIHOLE_DNS_}" ]; then
        echo "  [i] Setting DNS servers based on PIHOLE_DNS_ variable"
        # Remove any PIHOLE_DNS_ entries from setupVars.conf, if they exist
        sed -i '/PIHOLE_DNS_/d' /etc/pihole/setupVars.conf
        # Split into an array (delimited by ;)
        # Loop through and add them one by one to setupVars.conf
        IFS=";" read -r -a PIHOLE_DNS_ARR <<< "${PIHOLE_DNS_}"
        count=1
        valid_entries=0
        for i in "${PIHOLE_DNS_ARR[@]}"; do
            # Ensure we don't have an empty value first (see https://github.com/pi-hole/docker-pi-hole/issues/1174#issuecomment-1228763422 )
            if [ -n "$i" ]; then
              if valid_ip "$i" || valid_ip6 "$i" ; then
                change_setting "PIHOLE_DNS_$count" "$i"
                ((count=count+1))
                ((valid_entries=valid_entries+1))
                continue
              fi
              # shellcheck disable=SC2086
              if [ -n "$(dig +short ${i//#*/})" ]; then
                # If the "address" is a domain (for example a docker link) then try to resolve it and add
                # the result as a DNS server in setupVars.conf.
                resolved_ip="$(dig +short ${i//#*/} | head -n 1)"
                if [ -n "${i//*#/}" ] && [ "${i//*#/}" != "${i//#*/}" ]; then
                    resolved_ip="${resolved_ip}#${i//*#/}"
                fi
                echo "Resolved ${i} from PIHOLE_DNS_ as: ${resolved_ip}"
                if valid_ip "$resolved_ip" || valid_ip6 "$resolved_ip" ; then
                    change_setting "PIHOLE_DNS_$count" "$resolved_ip"
                    ((count=count+1))
                    ((valid_entries=valid_entries+1))
                    continue
                fi
              fi
              # If the above tests fail then this is an invalid DNS server
              echo "  [!] Invalid entry detected in PIHOLE_DNS_: ${i}"
            fi
        done

        if [ $valid_entries -eq 0 ]; then
            echo "  [!] No Valid entries detected in PIHOLE_DNS_. Aborting"
            exit 1
        fi
    else
        # Environment variable has not been set, but there may be existing values in an existing setupVars.conf
        # if this is the case, we do not want to overwrite these with the defaults of 8.8.8.8 and 8.8.4.4
        # Pi-hole can run with only one upstream configured, so we will just check for one.
        setupVarsDNS="$(grep 'PIHOLE_DNS_' /etc/pihole/setupVars.conf || true)"

        if [ -z "${setupVarsDNS}" ]; then
            echo "  [i] Configuring default DNS servers: 8.8.8.8, 8.8.4.4"
            change_setting "PIHOLE_DNS_1" "8.8.8.8"
            change_setting "PIHOLE_DNS_2" "8.8.4.4"
        else
            echo "  [i] Existing DNS servers detected in setupVars.conf. Leaving them alone"
        fi
    fi
}

setup_FTL_ProcessDNSSettings(){
    # Commit settings to 01-pihole.conf

    # shellcheck source=/dev/null
    . /opt/pihole/webpage.sh
    ProcessDNSSettings
}

setup_lighttpd_bind() {
    local serverip="${FTLCONF_LOCAL_IPV4}"
    # if using '--net=host' only bind lighttpd on $FTLCONF_LOCAL_IPV4 and localhost
    if grep -q "docker" /proc/net/dev && [[ $serverip != 0.0.0.0 ]]; then #docker (docker0 by default) should only be present on the host system
        if ! grep -q "server.bind" /etc/lighttpd/lighttpd.conf ; then # if the declaration is already there, don't add it again
            sed -i -E "s/server\.port\s+\=\s+([0-9]+)/server.bind\t\t = \"${serverip}\"\nserver.port\t\t = \1\n"\$SERVER"\[\"socket\"\] == \"127\.0\.0\.1:\1\" \{\}/" /etc/lighttpd/lighttpd.conf
        fi
    fi
}

setup_web_php_env() {
    if [ -z "$VIRTUAL_HOST" ] ; then
      VIRTUAL_HOST="$FTLCONF_LOCAL_IPV4"
    fi;

    for config_var in "VIRTUAL_HOST" "CORS_HOSTS" "PHP_ERROR_LOG" "PIHOLE_DOCKER_TAG" "TZ"; do
      local beginning_of_line="\t\t\t\"${config_var}\" => "
      if grep -qP "$beginning_of_line" "$PHP_ENV_CONFIG" ; then
        # replace line if already present
        sed -i "/${beginning_of_line}/c\\${beginning_of_line}\"${!config_var}\"," "$PHP_ENV_CONFIG"
      else
        # add line otherwise
        sed -i "/bin-environment/ a\\${beginning_of_line}\"${!config_var}\"," "$PHP_ENV_CONFIG"
      fi
    done

    echo "  [i] Added ENV to php:"
    grep -E '(VIRTUAL_HOST|CORS_HOSTS|PHP_ERROR_LOG|PIHOLE_DOCKER_TAG|TZ)' "$PHP_ENV_CONFIG"
}

setup_web_port() {
    local warning="  [!] WARNING: Custom WEB_PORT not used"
    # Quietly exit early for empty or default
    if [[ -z "${WEB_PORT}" || "${WEB_PORT}" == '80' ]] ; then return ; fi

    if ! echo "$WEB_PORT" | grep -q '^[0-9][0-9]*$' ; then
        echo "$warning - $WEB_PORT is not an integer"
        return
    fi

    local -i web_port="$WEB_PORT"
    if (( web_port < 1 || web_port > 65535 )); then
        echo "$warning - $web_port is not within valid port range of 1-65535"
        return
    fi
    echo "  [i] Custom WEB_PORT set to $web_port"
    echo "  [i] Without proper router DNAT forwarding to $FTLCONF_LOCAL_IPV4:$web_port, you may not get any blocked websites on ads"

    # Update lighttpd's port
    sed -i '/server.port\s*=\s*80\s*$/ s/80/'"${WEB_PORT}"'/g' /etc/lighttpd/lighttpd.conf

}

setup_web_theme(){
    # Parse the WEBTHEME variable, if it exists, and set the selected theme if it is one of the supported values.
    # If an invalid theme name was supplied, setup WEBTHEME to use the default-light theme.
    if [ -n "${WEBTHEME}" ]; then
        case "${WEBTHEME}" in
        "default-dark" | "default-darker" | "default-light" | "default-auto" | "lcars")
            echo "  [i] Setting Web Theme based on WEBTHEME variable, using value ${WEBTHEME}"
            change_setting "WEBTHEME" "${WEBTHEME}"
            ;;
        *)
            echo "  [!] Invalid theme name supplied: ${WEBTHEME}, falling back to default-light."
            change_setting "WEBTHEME" "default-light"
            ;;
        esac
    fi
}

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

        # Exit if setupvars already has a password
        setup_var_exists "WEBPASSWORD" && return
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

setup_ipv4_ipv6() {
    local ip_versions="IPv4 and IPv6"
    if [ "${IPv6,,}" != "true" ] ; then
        ip_versions="IPv4"
        sed -i '/use-ipv6.pl/ d' /etc/lighttpd/lighttpd.conf
    fi;
    echo "  [i] Using $ip_versions"
}

test_configs() {
    set -e
    echo -n '  [i] Testing lighttpd config: '
    lighttpd -t -f /etc/lighttpd/lighttpd.conf || exit 1
    set +e
    echo "  [i] All config checks passed, cleared for startup ..."
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

setup_var_exists() {
    local KEY="$1"
    if [ -n "$2" ]; then
        local REQUIRED_VALUE="[^\n]+"
    fi
    if grep -Pq "^${KEY}=${REQUIRED_VALUE}" "$setupVars"; then
        echo "  [i] Pre existing ${KEY} found"
        true
    else
        false
    fi
}

setup_web_temp_unit() {
  local UNIT="${TEMPERATUREUNIT}"
  # check if var is empty
  if [[ "$UNIT" != "" ]] ; then
      # check if we have valid units
      if [[ "$UNIT" == "c" || "$UNIT" == "k" || $UNIT == "f" ]] ; then
          pihole -a -"${UNIT}"
      fi
  fi
}

setup_web_layout() {
  local LO="${WEBUIBOXEDLAYOUT}"
  # check if var is empty
  if [[ "$LO" != "" ]] ; then
      # check if we have valid types boxed | traditional
      if [[ "$LO" == "traditional" || "$LO" == "boxed" ]] ; then
          change_setting "WEBUIBOXEDLAYOUT" "$WEBUIBOXEDLAYOUT"
      fi
  fi
}
