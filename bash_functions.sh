#!/bin/bash
# Some of the bash_functions use variables these core pi-hole/web scripts
. /opt/pihole/webpage.sh

fix_capabilities() {
    setcap CAP_NET_BIND_SERVICE,CAP_NET_RAW,CAP_NET_ADMIN,CAP_SYS_NICE,CAP_CHOWN+ei $(which pihole-FTL) || ret=$?

    if [[ $ret -ne 0 && "${DNSMASQ_USER:-pihole}" != "root" ]]; then
        echo "ERROR: Unable to set capabilities for pihole-FTL. Cannot run as non-root."
        echo "       If you are seeing this error, please set the environment variable 'DNSMASQ_USER' to the value 'root'"
        exit 1
    fi
}

prepare_configs() {
    # Done in /start.sh, don't do twice
    PH_TEST=true . "${PIHOLE_INSTALL}"
    # Set Debian webserver variables for installConfigs
    LIGHTTPD_USER="www-data"
    LIGHTTPD_GROUP="www-data"
    LIGHTTPD_CFG="lighttpd.conf.debian"
    installConfigs
    touch "$setupVars"
    set +e
    mkdir -p /var/run/pihole /var/log/pihole
    # Re-apply perms from basic-install over any volume mounts that may be present (or not)
    # Also  similar to preflights for FTL https://github.com/pi-hole/pi-hole/blob/master/advanced/Templates/pihole-FTL.service
    chown pihole:root /etc/lighttpd
    chown pihole:pihole "${PI_HOLE_CONFIG_DIR}/pihole-FTL.conf" "/var/log/pihole"
    chmod 644 "${PI_HOLE_CONFIG_DIR}/pihole-FTL.conf" "${PI_HOLE_CONFIG_DIR}/pihole-FTL.db"
    if [[ -e "${PI_HOLE_CONFIG_DIR}/pihole-FTL.db" ]]; then
      chown pihole:pihole "${PI_HOLE_CONFIG_DIR}/pihole-FTL.db"
      chmod 644 "${PI_HOLE_CONFIG_DIR}/pihole-FTL.db"
    fi
    touch /var/log/pihole-FTL.log /run/pihole-FTL.pid /run/pihole-FTL.port /var/log/pihole.log
    chown pihole:pihole /var/run/pihole /var/log/pihole
    test -f /var/run/pihole/FTL.sock && rm /var/run/pihole/FTL.sock
    chown pihole:pihole /var/log/pihole-FTL.log /run/pihole-FTL.pid /run/pihole-FTL.port /etc/pihole /var/log/pihole.log
    if [[ -e /etc/pihole/dhcp.leases ]]; then
      chown pihole:pihole /etc/pihole/dhcp.leases
    fi
    chmod 0644 /var/log/pihole-FTL.log /run/pihole-FTL.pid /run/pihole-FTL.port /var/log/pihole.log
    set -e
    # Update version numbers
    pihole updatechecker
    # Re-write all of the setupVars to ensure required ones are present (like QUERY_LOGGING)

    # If the setup variable file exists,
    if [[ -e "${setupVars}" ]]; then
        cp -f "${setupVars}" "${setupVars}.update.bak"
    fi
}

validate_env() {
    # Optional ServerIP is a valid IP
    # nc won't throw any text based errors when it times out connecting to a valid IP, otherwise it complains about the DNS name being garbage
    # if nc doesn't behave as we expect on a valid IP the routing table should be able to look it up and return a 0 retcode
    if [[ "$(nc -4 -w1 -z "$ServerIP" 53 2>&1)" != "" ]] && ! ip route get "$ServerIP" > /dev/null ; then
        echo "ERROR: ServerIP Environment variable ($ServerIP) doesn't appear to be a valid IPv4 address"
        exit 1
    fi

    # Optional IPv6 is a valid address
    if [[ -n "$ServerIPv6" ]] ; then
        if [[ "$ServerIPv6" == 'kernel' ]] ; then
            echo "ERROR: You passed in IPv6 with a value of 'kernel', this maybe beacuse you do not have IPv6 enabled on your network"
            unset ServerIPv6
            exit 1
        fi
        if [[ "$(nc -6 -w1 -z "$ServerIPv6" 53 2>&1)" != "" ]] && ! ip route get "$ServerIPv6" > /dev/null ; then
            echo "ERROR: ServerIPv6 Environment variable ($ServerIPv6) doesn't appear to be a valid IPv6 address"
            echo "  TIP: If your server is not IPv6 enabled just remove '-e ServerIPv6' from your docker container"
            exit 1
        fi
    fi;
}

setup_dnsmasq_interface() {
    local interface="${1:-eth0}"
    local interfaceType='default'
    if [ "$interface" != 'eth0' ] ; then
      interfaceType='custom'
    fi;
    echo "DNSMasq binding to $interfaceType interface: $interface"
    [ -n "$interface" ] && change_setting "PIHOLE_INTERFACE" "${interface}"
}

setup_dnsmasq_listening_behaviour() {
    local dnsmasq_listening_behaviour="${1}"

    if [ -n "$dnsmasq_listening_behaviour" ]; then
      change_setting "DNSMASQ_LISTENING" "${dnsmasq_listening_behaviour}"
    fi;
}

setup_dnsmasq_config_if_missing() {
    # When fresh empty directory volumes are used we miss this file
    if [ ! -f /etc/dnsmasq.d/01-pihole.conf ] ; then
        cp /etc/.pihole/advanced/01-pihole.conf /etc/dnsmasq.d/
    fi;
}

setup_dnsmasq() {
    local interface="$1"
    local dnsmasq_listening_behaviour="$2"
    # Coordinates
    setup_dnsmasq_config_if_missing
    setup_dnsmasq_interface "$interface"
    setup_dnsmasq_listening_behaviour "$dnsmasq_listening_behaviour"
    setup_dnsmasq_user "${DNSMASQ_USER}"
    setup_cache_size "${CUSTOM_CACHE_SIZE}"
    ProcessDNSSettings
}

setup_dnsmasq_user() {
    local DNSMASQ_USER="${1}"

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

setup_dnsmasq_hostnames() {
    # largely borrowed from automated install/basic-install.sh
    local IPV4_ADDRESS="${1}"
    local IPV6_ADDRESS="${2}"
    local hostname="${3}"
    local dnsmasq_pihole_01_location="/etc/dnsmasq.d/01-pihole.conf"

    if [ -z "$hostname" ]; then
        if [[ -f /etc/hostname ]]; then
            hostname=$(</etc/hostname)
        elif [ -x "$(command -v hostname)" ]; then
            hostname=$(hostname -f)
        fi
    fi;

    if [[ "${IPV4_ADDRESS}" != "" ]]; then
        tmp=${IPV4_ADDRESS%/*}
        sed -i "s/@IPV4@/$tmp/" ${dnsmasq_pihole_01_location}
    else
        sed -i '/^address=\/pi.hole\/@IPV4@/d' ${dnsmasq_pihole_01_location}
        sed -i '/^address=\/@HOSTNAME@\/@IPV4@/d' ${dnsmasq_pihole_01_location}
    fi

    if [[ "${IPV6_ADDRESS}" != "" ]]; then
        sed -i "s/@IPv6@/$IPV6_ADDRESS/" ${dnsmasq_pihole_01_location}
    else
        sed -i '/^address=\/pi.hole\/@IPv6@/d' ${dnsmasq_pihole_01_location}
        sed -i '/^address=\/@HOSTNAME@\/@IPv6@/d' ${dnsmasq_pihole_01_location}
    fi

    if [[ "${hostname}" != "" ]]; then
        sed -i "s/@HOSTNAME@/$hostname/" ${dnsmasq_pihole_01_location}
    else
        sed -i '/^address=\/@HOSTNAME@*/d' ${dnsmasq_pihole_01_location}
    fi
}

setup_cache_size() {
    local warning="WARNING: CUSTOM_CACHE_SIZE not used"
    local dnsmasq_pihole_01_location="/etc/dnsmasq.d/01-pihole.conf"
    # Quietly exit early for empty or default
    if [[ -z "${1}" || "${1}" == '10000' ]] ; then return ; fi

    if [[ "${DNSSEC}" == "true" ]] ; then
        echo "$warning - Cannot change cache size if DNSSEC is enabled"
        return
    fi

    if ! echo $1 | grep -q '^[0-9]*$' ; then
        echo "$warning - $1 is not an integer"
        return
    fi

    local -i custom_cache_size="$1"
    if (( $custom_cache_size < 0 )); then
        echo "$warning - $custom_cache_size is not a positive integer or zero"
        return
    fi
    echo "Custom CUSTOM_CACHE_SIZE set to $custom_cache_size"

    sed -i "s/^cache-size=\s*[0-9]*/cache-size=$custom_cache_size/" ${dnsmasq_pihole_01_location}
}

setup_lighttpd_bind() {
    local serverip="$1"
    # if using '--net=host' only bind lighttpd on $ServerIP and localhost
    if grep -q "docker" /proc/net/dev && [[ $serverip != 0.0.0.0 ]]; then #docker (docker0 by default) should only be present on the host system
        if ! grep -q "server.bind" /etc/lighttpd/lighttpd.conf ; then # if the declaration is already there, don't add it again
            sed -i -E "s/server\.port\s+\=\s+([0-9]+)/server.bind\t\t = \"${serverip}\"\nserver.port\t\t = \1\n"\$SERVER"\[\"socket\"\] == \"127\.0\.0\.1:\1\" \{\}/" /etc/lighttpd/lighttpd.conf
        fi
    fi
}

setup_php_env() {
    if [ -z "$VIRTUAL_HOST" ] ; then
      VIRTUAL_HOST="$ServerIP"
    fi;

    for config_var in "VIRTUAL_HOST" "CORS_HOSTS" "ServerIP" "PHP_ERROR_LOG" "PIHOLE_DOCKER_TAG"; do
      local beginning_of_line="\t\t\t\"${config_var}\" => "
      if grep -qP "$beginning_of_line" "$PHP_ENV_CONFIG" ; then
        # replace line if already present
        sed -i "/${beginning_of_line}/c\\${beginning_of_line}\"${!config_var}\"," "$PHP_ENV_CONFIG"
      else
        # add line otherwise
        sed -i "/bin-environment/ a\\${beginning_of_line}\"${!config_var}\"," "$PHP_ENV_CONFIG"
      fi
    done

    echo "Added ENV to php:"
    grep -E '(VIRTUAL_HOST|CORS_HOSTS|ServerIP|PHP_ERROR_LOG|PIHOLE_DOCKER_TAG)' "$PHP_ENV_CONFIG"
}

setup_web_port() {
    local warning="WARNING: Custom WEB_PORT not used"
    # Quietly exit early for empty or default
    if [[ -z "${1}" || "${1}" == '80' ]] ; then return ; fi

    if ! echo $1 | grep -q '^[0-9][0-9]*$' ; then
        echo "$warning - $1 is not an integer"
        return
    fi

    local -i web_port="$1"
    if (( $web_port < 1 || $web_port > 65535 )); then
        echo "$warning - $web_port is not within valid port range of 1-65535"
        return
    fi
    echo "Custom WEB_PORT set to $web_port"
    echo "INFO: Without proper router DNAT forwarding to $ServerIP:$web_port, you may not get any blocked websites on ads"

    # Update lighttpd's port
    sed -i '/server.port\s*=\s*80\s*$/ s/80/'$WEB_PORT'/g' /etc/lighttpd/lighttpd.conf

}

load_web_password_secret() {
   # If WEBPASSWORD is not set at all, attempt to read password from WEBPASSWORD_FILE,
   # allowing secrets to be passed via docker secrets
   if [ -z "${WEBPASSWORD+x}" ] && [ -n "${WEBPASSWORD_FILE}" ] && [ -r "${WEBPASSWORD_FILE}" ]; then
     WEBPASSWORD=$(<"${WEBPASSWORD_FILE}")
   fi;
}

generate_password() {
    if [ -z "${WEBPASSWORD+x}" ] ; then
        # Not set at all, give the user a random pass
        WEBPASSWORD=$(tr -dc _A-Z-a-z-0-9 < /dev/urandom | head -c 8)
        echo "Assigning random password: $WEBPASSWORD"
    fi;
}

setup_web_password() {
    setup_var_exists "WEBPASSWORD" && return

    PASS="$1"
    # Explicitly turn off bash printing when working with secrets
    { set +x; } 2>/dev/null

    if [[ "$PASS" == "" ]] ; then
        echo "" | pihole -a -p
    else
        pihole -a -p "$PASS" "$PASS"
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
    echo "Using $ip_versions"
}

test_configs() {
    set -e
    echo -n '::: Testing pihole-FTL DNS: '
    sudo -u ${DNSMASQ_USER:-root} pihole-FTL test || exit 1
    echo -n '::: Testing lighttpd config: '
    lighttpd -t -f /etc/lighttpd/lighttpd.conf || exit 1
    set +e
    echo "::: All config checks passed, cleared for startup ..."
}

setup_blocklists() {
    local blocklists="$1"
    # Exit/return early without setting up adlists with defaults for any of the following conditions:
    # 1. skip_setup_blocklists env is set
    exit_string="(exiting ${FUNCNAME[0]} early)"

    if [ -n "${skip_setup_blocklists}" ]; then
        echo "::: skip_setup_blocklists requested ($exit_string)"
        return
    fi

    # 2. The adlist file exists already (restarted container or volume mounted list)
    if [ -f "${adlistFile}" ]; then
        echo "::: Preexisting ad list ${adlistFile} detected ($exit_string)"
        cat "${adlistFile}"
        return
    fi

    echo "::: ${FUNCNAME[0]} now setting default blocklists up: "
    echo "::: TIP: Use a docker volume for ${adlistFile} if you want to customize for first boot"
    installDefaultBlocklists

    echo "::: Blocklists (${adlistFile}) now set to:"
    cat "${adlistFile}"
}

setup_var_exists() {
    local KEY="$1"
    if [ -n "$2" ]; then
        local REQUIRED_VALUE="[^\n]+"
    fi
    if grep -Pq "^${KEY}=${REQUIRED_VALUE}" "$setupVars"; then
        echo "::: Pre existing ${KEY} found"
        true
    else
        false
    fi
}

setup_temp_unit() {
  local UNIT="$1"
  # check if var is empty
  if [[ "$UNIT" != "" ]] ; then
      # check if we have valid units
      if [[ "$UNIT" == "c" || "$UNIT" == "k" || $UNIT == "f" ]] ; then
          pihole -a -${UNIT}
      fi
  fi
}

setup_ui_layout() {
  local LO=$1
  # check if var is empty
  if [[ "$LO" != "" ]] ; then
      # check if we have valid types boxed | traditional
      if [[ "$LO" == "traditional" || "$LO" == "boxed" ]] ; then
          change_setting "WEBUIBOXEDLAYOUT" "$WEBUIBOXEDLAYOUT"
      fi
  fi
}

setup_admin_email() {
  local EMAIL=$1
  # check if var is empty
  if [[ "$EMAIL" != "" ]] ; then
      pihole -a -e "$EMAIL"
  fi
}

setup_dhcp() {
  if [ -z "${DHCP_START}" ] || [ -z "${DHCP_END}" ] || [ -z "${DHCP_ROUTER}" ]; then
    echo "ERROR: Won't enable DHCP server because mandatory Environment variables are missing: DHCP_START, DHCP_END and/or DHCP_ROUTER"
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
