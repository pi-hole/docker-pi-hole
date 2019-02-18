#!/bin/bash
# Some of the bash_functions use variables these core pi-hole/web scripts
. /opt/pihole/webpage.sh

docker_checks() {
    warn_msg='WARNING Misconfigured DNS in /etc/resolv.conf'
    ns_count="$(grep -c nameserver /etc/resolv.conf)"
    ns_primary="$(grep nameserver /etc/resolv.conf | head -1)"
    ns_primary="${ns_primary/nameserver /}"
    warned=false

    if [ "$ns_count" -lt 2 ] ; then
        echo "$warn_msg: Two DNS servers are recommended, 127.0.0.1 and any backup server"
        warned=true
    fi

    if [ "$ns_primary" != "127.0.0.1" ] ; then
        echo "$warn_msg: Primary DNS should be 127.0.0.1 (found ${ns_primary})"
        warned=true
    fi

    if ! $warned ; then
        echo "OK: Checks passed for /etc/resolv.conf DNS servers"
    fi

    echo
    cat /etc/resolv.conf
}

fix_capabilities() {
    setcap CAP_NET_BIND_SERVICE,CAP_NET_RAW,CAP_NET_ADMIN+ei $(which pihole-FTL) || ret=$?

    if [[ $ret -ne 0 && "${DNSMASQ_USER:-root}" != "root" ]]; then
        echo "ERROR: Failed to set capabilities for pihole-FTL. Cannot run as non-root."
        exit 1
    fi
}

prepare_configs() {
    # Done in /start.sh, don't do twice
    PH_TEST=true . $PIHOLE_INSTALL
    distro_check
    installConfigs
    touch "$setupVars"
    set +e
    mkdir -p /var/run/pihole /var/log/pihole
    # Re-apply perms from basic-install over any volume mounts that may be present (or not)
    # Also  similar to preflights for FTL https://github.com/pi-hole/pi-hole/blob/master/advanced/Templates/pihole-FTL.service
    chown pihole:root /etc/lighttpd
    chown pihole:pihole "${PI_HOLE_CONFIG_DIR}/pihole-FTL.conf" "/var/log/pihole" "${regexFile}"
    chmod 644 "${PI_HOLE_CONFIG_DIR}/pihole-FTL.conf" 
    # not sure why pihole:pihole user/group write perms are not enough for web to write...dirty fix:
    chmod 777 "${regexFile}"
    touch /var/log/pihole-FTL.log /run/pihole-FTL.pid /run/pihole-FTL.port /var/log/pihole.log
    chown pihole:pihole /var/run/pihole /var/log/pihole
    test -f /var/run/pihole/FTL.sock && rm /var/run/pihole/FTL.sock
    chown pihole:pihole /var/log/pihole-FTL.log /run/pihole-FTL.pid /run/pihole-FTL.port /etc/pihole /etc/pihole/dhcp.leases /var/log/pihole.log
    chmod 0644 /var/log/pihole-FTL.log /run/pihole-FTL.pid /run/pihole-FTL.port /var/log/pihole.log
    set -e
    # Update version numbers
    pihole updatechecker
    # Re-write all of the setupVars to ensure required ones are present (like QUERY_LOGGING)
    
    # If the setup variable file exists,
    if [[ -e "${setupVars}" ]]; then
        # update the variables in the file
        local USERWEBPASSWORD="${WEBPASSWORD}"
        . "${setupVars}"
        # Stash and pop the user password to avoid setting the password to the hashed setupVar variable
        WEBPASSWORD="${USERWEBPASSWORD}"
        # Clean up old before re-writing the required setupVars
        sed -i.update.bak '/PIHOLE_INTERFACE/d;/IPV4_ADDRESS/d;/IPV6_ADDRESS/d;/QUERY_LOGGING/d;/INSTALL_WEB_SERVER/d;/INSTALL_WEB_INTERFACE/d;/LIGHTTPD_ENABLED/d;' "${setupVars}"
    fi
    # echo the information to the user
    {
    echo "PIHOLE_INTERFACE=${PIHOLE_INTERFACE}"
    echo "IPV4_ADDRESS=${IPV4_ADDRESS}"
    echo "IPV6_ADDRESS=${IPV6_ADDRESS}"
    echo "QUERY_LOGGING=${QUERY_LOGGING}"
    echo "INSTALL_WEB_SERVER=${INSTALL_WEB_SERVER}"
    echo "INSTALL_WEB_INTERFACE=${INSTALL_WEB_INTERFACE}"
    echo "LIGHTTPD_ENABLED=${LIGHTTPD_ENABLED}"
    }>> "${setupVars}"
}

validate_env() {
    # Optional ServerIP is a valid IP
    # nc won't throw any text based errors when it times out connecting to a valid IP, otherwise it complains about the DNS name being garbage
    # if nc doesn't behave as we expect on a valid IP the routing table should be able to look it up and return a 0 retcode
    if [[ "$(nc -4 -w1 -z "$ServerIP" 53 2>&1)" != "" ]] || ! ip route get "$ServerIP" > /dev/null ; then
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
        if [[ "$(nc -6 -w1 -z "$ServerIPv6" 53 2>&1)" != "" ]] || ! ip route get "$ServerIPv6" > /dev/null ; then
            echo "ERROR: ServerIPv6 Environment variable ($ServerIPv6) doesn't appear to be a valid IPv6 address"
            echo "  TIP: If your server is not IPv6 enabled just remove '-e ServerIPv6' from your docker container"
            exit 1
        fi
    fi;
}

setup_dnsmasq_dns() {
    . /opt/pihole/webpage.sh
    local DNS1="${1:-8.8.8.8}"
    local DNS2="${2:-8.8.4.4}"
    local dnsType='default'
    if [ "$DNS1" != '8.8.8.8' ] || [ "$DNS2" != '8.8.4.4' ] ; then
        dnsType='custom'
    fi;

    # TODO With the addition of this to /start.sh this needs a refactor
    if [ ! -f /.piholeFirstBoot ] ; then
        local setupDNS1="$(grep 'PIHOLE_DNS_1' ${setupVars})"
        local setupDNS2="$(grep 'PIHOLE_DNS_2' ${setupVars})"
        setupDNS1="${setupDNS1/PIHOLE_DNS_1=/}"
        setupDNS2="${setupDNS2/PIHOLE_DNS_2=/}"
        if [[ -n "$DNS1" && -n "$setupDNS1"  ]] || \
           [[ -n "$DNS2" && -n "$setupDNS2"  ]] ; then 
                echo "Docker DNS variables not used"
        fi
        echo "Existing DNS servers used (${setupDNS1:-unset} & ${setupDNS2:-unset})"
        return
    fi

    echo "Using $dnsType DNS servers: $DNS1 & $DNS2"
    if [[ -n "$DNS1" && -z "$setupDNS1" ]] ; then
        change_setting "PIHOLE_DNS_1" "${DNS1}"
    fi
    if [[ -n "$DNS2" && -z "$setupDNS2" ]] ; then
        if [[ "$DNS2" == "no" ]] ; then
            delete_setting "PIHOLE_DNS_2"
            unset PIHOLE_DNS_2
        else
            change_setting "PIHOLE_DNS_2" "${DNS2}"
        fi
    fi
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
    local dns1="$1"
    local dns2="$2"
    local interface="$3"
    local dnsmasq_listening_behaviour="$4"
    # Coordinates 
    setup_dnsmasq_config_if_missing
    setup_dnsmasq_dns "$dns1" "$dns2" 
    setup_dnsmasq_interface "$interface"
    setup_dnsmasq_listening_behaviour "$dnsmasq_listening_behaviour"
    setup_dnsmasq_user "${DNSMASQ_USER}"
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

setup_lighttpd_bind() {
    local serverip="$1"
    # if using '--net=host' only bind lighttpd on $ServerIP and localhost
    if grep -q "docker" /proc/net/dev ; then #docker (docker0 by default) should only be present on the host system
        if ! grep -q "server.bind" /etc/lighttpd/lighttpd.conf ; then # if the declaration is already there, don't add it again
            sed -i -E "s/server\.port\s+\=\s+([0-9]+)/server.bind\t\t = \"${serverip}\"\nserver.port\t\t = \1\n"\$SERVER"\[\"socket\"\] == \"127\.0\.0\.1:\1\" \{\}/" /etc/lighttpd/lighttpd.conf
        fi
    fi
}

setup_php_env() {
    if [ -z "$VIRTUAL_HOST" ] ; then
      VIRTUAL_HOST="$ServerIP"
    fi;
    local vhost_line="\t\t\t\"VIRTUAL_HOST\" => \"${VIRTUAL_HOST}\","
    local serverip_line="\t\t\t\"ServerIP\" => \"${ServerIP}\","
    local php_error_line="\t\t\t\"PHP_ERROR_LOG\" => \"${PHP_ERROR_LOG}\","

    # idempotent line additions
    grep -qP "$vhost_line" "$PHP_ENV_CONFIG" || \
        sed -i "/bin-environment/ a\\${vhost_line}" "$PHP_ENV_CONFIG"
    grep -qP "$serverip_line" "$PHP_ENV_CONFIG" || \
        sed -i "/bin-environment/ a\\${serverip_line}" "$PHP_ENV_CONFIG"
    grep -qP "$php_error_line" "$PHP_ENV_CONFIG" || \
        sed -i "/bin-environment/ a\\${php_error_line}" "$PHP_ENV_CONFIG"

    echo "Added ENV to php:"
    grep -E '(VIRTUAL_HOST|ServerIP|PHP_ERROR_LOG)' "$PHP_ENV_CONFIG"
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
    # Update any default port 80 references in the HTML
    grep -Prl '://127\.0\.0\.1/' /var/www/html/ | xargs -r sed -i "s|/127\.0\.0\.1/|/127.0.0.1:${WEB_PORT}/|g"
    grep -Prl '://pi\.hole/' /var/www/html/ | xargs -r sed -i "s|/pi\.hole/|/pi\.hole:${WEB_PORT}/|g"

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
    # Turn bash debug on while setting up password (to print it)
    if [[ "$PASS" == "" ]] ; then
        echo "" | pihole -a -p
    else
        echo "Setting password: ${PASS}"
        set -x
        pihole -a -p "$PASS" "$PASS"
    fi
    # Turn bash debug back off after print password setup
    # (subshell to null hides printing output)
    { set +x; } 2>/dev/null

    # To avoid printing this if conditional in bash debug, turn off  debug above..
    # then re-enable debug if necessary (more code but cleaner printed output)
    if [ "${PH_VERBOSE:-0}" -gt 0 ] ; then
        set -x
    fi
}

setup_ipv4_ipv6() {
    local ip_versions="IPv4 and IPv6"
    if [ "$IPv6" != "True" ] ; then
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

