validate_env() {
    if [ -z "$ServerIP" ] ; then
      echo "ERROR: To function correctly you must pass an environment variables of 'ServerIP' into the docker container with the IP of your docker host from which you are passing web (80) and dns (53) ports from"
      exit 1
    fi;
}

setup_saved_variables() {
    # /tmp/piholeIP is the current override of auto-lookup in gravity.sh
    echo "$ServerIP" > /etc/pihole/piholeIP;
    echo "IPv4_address=$ServerIP" > /etc/pihole/setupVars.conf;
    echo "IPv6_address=$ServerIPv6" >> /etc/pihole/setupVars.conf;
}

setup_dnsmasq() {
    local DNS1="${1:-8.8.8.8}"
    local DNS2="${2:-8.8.4.4}"
    local dnsType='default'
    if [ "$DNS1" != '8.8.8.8' ] || [ "$DNS2" != '8.8.4.4' ] ; then
      dnsType='custom'
    fi;

    echo "Using $dnsType DNS servers: $DNS1 & $DNS2"
    sed -i "s/@DNS1@/$DNS1/" /etc/dnsmasq.d/01-pihole.conf && \
    sed -i "s/@DNS2@/$DNS2/" /etc/dnsmasq.d/01-pihole.conf
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
    grep -q "$vhost_line" $PHP_ENV_CONFIG || \
        sed -i "/bin-environment/ a\\${vhost_line}" $PHP_ENV_CONFIG
    grep -q "$serverip_line" $PHP_ENV_CONFIG || \
        sed -i "/bin-environment/ a\\${serverip_line}" $PHP_ENV_CONFIG
    grep -q "$php_error_line" $PHP_ENV_CONFIG || \
        sed -i "/bin-environment/ a\\${php_error_line}" $PHP_ENV_CONFIG

    echo "Added ENV to php:"
    grep -E '(VIRTUAL_HOST|ServerIP|PHP_ERROR_LOG)' $PHP_ENV_CONFIG
}

setup_php_env_alpine() {
    echo "[www]" > $PHP_ENV_CONFIG;
    echo "env[PATH] = ${PATH}" >> $PHP_ENV_CONFIG;
    echo "env[PHP_ERROR_LOG] = ${PHP_ERROR_LOG}" >> $PHP_ENV_CONFIG;
    echo "env[ServerIP] = ${ServerIP}" >> $PHP_ENV_CONFIG;

    if [ -z "$VIRTUAL_HOST" ] ; then
      VIRTUAL_HOST="$ServerIP"
    fi;
    echo "env[VIRTUAL_HOST] = ${VIRTUAL_HOST}" >> $PHP_ENV_CONFIG;

    echo "Added ENV to php:"
    cat $PHP_ENV_CONFIG
}

setup_ipv4_ipv6() {
    local ip_versions="IPv4 and IPv6"
    if [ "$IPv6" != "True" ] ; then
        ip_versions="IPv4"
        case $IMAGE in
            "debian") sed -i '/use-ipv6.pl/ d' /etc/lighttpd/lighttpd.conf ;;
            "alpine") sed -i '/listen \[::\]:80;/ d' /etc/nginx/nginx.conf ;;
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
    php-fpm -t
    echo -n '::: Testing NGINX config: '
    nginx -t
    set +e
    echo "::: All config checks passed, starting ..."
}

test_framework_stubbing() {
    if [ -n "$PYTEST" ] ; then sed -i 's/^gravity_spinup$/#donotcurl/g' `which gravity.sh`; fi;
}
