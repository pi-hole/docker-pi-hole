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
}

setup_dnsmasq_dns() {
    . /opt/pihole/webpage.sh
    local DNS1="${1:-8.8.8.8}"
    local DNS2="${2:-8.8.4.4}"
    local dnsType='default'
    if [ "$DNS1" != '8.8.8.8' ] || [ "$DNS2" != '8.8.4.4' ] ; then
      dnsType='custom'
    fi;

    echo "Using $dnsType DNS servers: $DNS1 & $DNS2"
	[ -n "$DNS1" ] && change_setting "PIHOLE_DNS_1" "${DNS1}"
	[ -n "$DNS2" ] && change_setting "PIHOLE_DNS_2" "${DNS2}"
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

setup_dnsmasq() {
    # Coordinates 
    setup_dnsmasq_dns "$DNS1" "$DNS2" 
    setup_dnsmasq_interface "$INTERFACE"
    ProcessDNSSettings
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

setup_php_env() {
    case $IMAGE in
        "debian") setup_php_env_debian ;;
        "alpine") setup_php_env_alpine ;;
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

setup_php_env_alpine() {
    # Intentionally tabs, required by HEREDOC de-indentation (<<-)
    cat <<-EOF > "$PHP_ENV_CONFIG"
		[www]
		env[PATH] = ${PATH}
		env[PHP_ERROR_LOG] = ${PHP_ERROR_LOG}
		env[ServerIP] = ${ServerIP}
	EOF

    if [ -z "$VIRTUAL_HOST" ] ; then
      VIRTUAL_HOST="$ServerIP"
    fi;
    echo "env[VIRTUAL_HOST] = ${VIRTUAL_HOST}" >> "$PHP_ENV_CONFIG";

    echo "Added ENV to php:"
    cat "$PHP_ENV_CONFIG"
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
        case $IMAGE in
            "debian") sed -i '/use-ipv6.pl/ d' /etc/lighttpd/lighttpd.conf ;;
            "alpine") sed -i '/listen \[::\]:80/ d' /etc/nginx/nginx.conf ;;
        esac
    fi;
    echo "Using $ip_versions"
}

test_configs() {
    case $IMAGE in
        "debian") test_configs_debian ;;
        "alpine") test_configs_alpine ;;
    esac
}

test_configs_debian() {
    set -e
    echo -n '::: Testing DNSmasq config: '
    dnsmasq --test -7 /etc/dnsmasq.d
    echo -n '::: Testing lighttpd config: '
    lighttpd -t -f /etc/lighttpd/lighttpd.conf
    set +e
    echo "::: All config checks passed, starting ..."
}

test_configs_alpine() {
    set -e
    echo -n '::: Testing DNSmasq config: '
    dnsmasq --test -7 /etc/dnsmasq.d
    echo -n '::: Testing PHP-FPM config: '
    php-fpm5 -t
    echo -n '::: Testing NGINX config: '
    nginx -t
    set +e
    echo "::: All config checks passed, starting ..."
}

test_framework_stubbing() {
    if [ -n "$PYTEST" ] ; then 
		echo ":::::: Tests are being ran - stub out ad list fetching and add a fake ad block"
		sed -i 's/^gravity_spinup$/#gravity_spinup # DISABLED FOR PYTEST/g' "$(which gravity.sh)" 
		echo 'testblock.pi-hole.local' >> /etc/pihole/blacklist.txt
	fi
}
