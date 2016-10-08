validate_env() {
    if [ -z "$ServerIP" ] ; then
      echo "ERROR: To function correctly you must pass an environment variables of 'ServerIP' into the docker container with the IP of your docker host from which you are passing web (80) and dns (53) ports from"
      exit 1
    fi;
}

setup_saved_variables() {
    # /tmp/piholeIP is the current override of auto-lookup in gravity.sh
    echo "$ServerIP" > /etc/pihole/piholeIP;
    echo "IPv4addr=$ServerIP" > /etc/pihole/setupVars.conf;
    echo "piholeIPv6=$ServerIPv6" >> /etc/pihole/setupVars.conf;
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
    if [ ! -f /var/run/dockerpihole-firstboot ] ; then
        case $IMAGE in
            "debian") setup_php_env_debian ;;
            "alpine") setup_php_env_alpine ;;
        esac

        touch /var/run/dockerpihole-firstboot
    else
        echo "Looks like you're restarting this container, skipping php env setup"
    fi;
}

setup_php_env_debian() {
    sed -i "/bin-environment/ a\\\t\t\t\"ServerIP\" => \"${ServerIP}\"," $PHP_ENV_CONFIG
    sed -i "/bin-environment/ a\\\t\t\t\"PHP_ERROR_LOG\" => \"${PHP_ERROR_LOG}\"," $PHP_ENV_CONFIG

    if [ -z "$VIRTUAL_HOST" ] ; then
      VIRTUAL_HOST="$ServerIP"
    fi;
    sed -i "/bin-environment/ a\\\t\t\t\"VIRTUAL_HOST\" => \"${VIRTUAL_HOST}\"," $PHP_ENV_CONFIG

    echo "Added ENV to php:"
    grep -E '(VIRTUAL_HOST|ServerIP)' $PHP_ENV_CONFIG
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
    if [ -n "$PYTEST" ] ; then sed -i 's/^gravity_spinup/#donotcurl/g' `which gravity.sh`; fi;
}
