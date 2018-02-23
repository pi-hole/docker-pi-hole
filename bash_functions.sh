#!/bin/bash
. /opt/pihole/webpage.sh
setupVars="$setupVars"
ServerIP="$ServerIP"
ServerIPv6="$ServerIPv6"
IPv6="$IPv6"

prepare_setup_vars() {
    touch "$setupVars"
}

validate_env() {
    if [ -z "$ServerIP" ] ; then
      echo "ERROR: To function correctly you must pass an environment variables of 'ServerIP' into the docker container with the IP of your docker host from which you are passing web (80) and dns (53) ports from"
      exit 1
    fi;

    # Required ServerIP is a valid IP
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

    if [ ! -f /.piholeFirstBoot ] ; then
        local setupDNS1="$(grep 'PIHOLE_DNS_1' ${setupVars})"
        local setupDNS2="$(grep 'PIHOLE_DNS_2' ${setupVars})"
        if [[ -n "$DNS1" && -n "$setupDNS1"  ]] || \
           [[ -n "$DNS2" && -n "$setupDNS2"  ]] ; then 
                echo "Docker DNS variables not used"
        fi
        echo "Existing DNS servers used"
        return
    fi

    echo "Using $dnsType DNS servers: $DNS1 & $DNS2"
    if [[ -n "$DNS1" && -z "$setupDNS1" ]] ; then
        change_setting "PIHOLE_DNS_1" "${DNS1}"
    fi
    if [[ -n "$DNS2" && -z "$setupDNS2" ]] ; then
        change_setting "PIHOLE_DNS_2" "${DNS2}"
    fi
}

setup_dnsmasq_interface() {
    local INTERFACE="${1:-eth0}"
    local interfaceType='default'
    if [ "$INTERFACE" != 'eth0' ] ; then
      interfaceType='custom'
    fi;
    echo "DNSMasq binding to $interfaceType interface: $INTERFACE"
    [ -n "$INTERFACE" ] && change_setting "PIHOLE_INTERFACE" "${INTERFACE}"
}

setup_dnsmasq_config_if_missing() {
    # When fresh empty directory volumes are used we miss this file
    if [ ! -f /etc/dnsmasq.d/01-pihole.conf ] ; then
        cp /etc/.pihole/advanced/01-pihole.conf /etc/dnsmasq.d/
    fi;
}

setup_dnsmasq() {
    # Coordinates 
    setup_dnsmasq_config_if_missing
    setup_dnsmasq_dns "$DNS1" "$DNS2" 
    setup_dnsmasq_interface "$INTERFACE"
    ProcessDNSSettings
    # dnsmasq -7 /etc/dnsmasq.d --interface="${INTERFACE:-eth0}"
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
    if [[ "$TAG" == 'debian' ]] ; then
    # if using '--net=host' only bind lighttpd on $ServerIP and localhost
        if grep -q "docker" /proc/net/dev ; then #docker (docker0 by default) should only be present on the host system
            if ! grep -q "server.bind" /etc/lighttpd/lighttpd.conf ; then # if the declaration is already there, don't add it again
                sed -i -E "s/server\.port\s+\=\s+80/server.bind\t\t = \"${ServerIP}\"\nserver.port\t\t = 80\n"\$SERVER"\[\"socket\"\] == \"127\.0\.0\.1:80\" \{\}/" /etc/lighttpd/lighttpd.conf
            fi
        fi
    fi
}

setup_php_env() {
    case $TAG in
        "debian") setup_php_env_debian ;;
    esac
}

setup_php_env_debian() {
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

setup_web_password() {
    if [ -z "${WEBPASSWORD+x}" ] ; then 
        # Not set at all, give the user a random pass
        WEBPASSWORD=$(tr -dc _A-Z-a-z-0-9 < /dev/urandom | head -c 8)
        echo "Assigning random password: $WEBPASSWORD"
    fi;
    set -x
    if [[ "$WEBPASSWORD" == "" ]] ; then
        echo "" | pihole -a -p
    else
        pihole -a -p "$WEBPASSWORD" "$WEBPASSWORD"
    fi
    { set +x; } 2>/dev/null
}

setup_ipv4_ipv6() {
    local ip_versions="IPv4 and IPv6"
    if [ "$IPv6" != "True" ] ; then
        ip_versions="IPv4"
        case $TAG in
            "debian") sed -i '/use-ipv6.pl/ d' /etc/lighttpd/lighttpd.conf ;;
        esac
    fi;
    echo "Using $ip_versions"
}

test_configs() {
    case $TAG in
        "debian") test_configs_debian ;;
    esac
}

test_configs_debian() {
    set -e
    echo -n '::: Testing DNSmasq config: '
    dnsmasq --test -7 /etc/dnsmasq.d || exit 1
    echo -n '::: Testing lighttpd config: '
    lighttpd -t -f /etc/lighttpd/lighttpd.conf || exit 1
    set +e
    echo "::: All config checks passed, starting ..."
}

test_framework_stubbing() {
    if [ -n "$PYTEST" ] ; then 
        echo ":::::: Tests are being ran - stub out ad list fetching and add a fake ad block"
        sed -i 's/^gravity_spinup$/#gravity_spinup # DISABLED FOR PYTEST/g' "$(which gravity.sh)" 
        echo '123.123.123.123 testblock.pi-hole.local' > /var/www/html/fake.list
        echo 'file:///var/www/html/fake.list' > /etc/pihole/adlists.list
        echo 'http://localhost/fake.list' >> /etc/pihole/adlists.list
    fi
}
