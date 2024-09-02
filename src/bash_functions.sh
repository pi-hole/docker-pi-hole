#!/bin/bash

# Some of the bash_functions use utilities from Pi-hole's utils.sh
# shellcheck disable=SC2154
# shellcheck source=/dev/null
# . /opt/pihole/utils.sh

#######################
# returns value from FTLs config file using pihole-FTL --config
#
# Takes one argument: key
# Example getFTLConfigValue dns.piholePTR
#######################
getFTLConfigValue() {
    pihole-FTL --config -q "${1}"
}

#######################
# sets value in FTLs config file using pihole-FTL --config
#
# Takes two arguments: key and value
# Example setFTLConfigValue dns.piholePTR PI.HOLE
#
# Note, for complex values such as dns.upstreams, you should wrap the value in single quotes:
# setFTLConfigValue dns.upstreams '[ "8.8.8.8" , "8.8.4.4" ]'
#######################
setFTLConfigValue() {
    pihole-FTL --config "${1}" "${2}" >/dev/null
}

set_uid_gid() {

    echo "  [i] Setting up user & group for the pihole user"

    currentUid=$(id -u pihole)

    # If PIHOLE_UID is set, modify the pihole group's id to match
    if [ -n "${PIHOLE_UID}" ]; then
        if [[ ${currentUid} -ne ${PIHOLE_UID} ]]; then
            echo "  [i] Changing ID for user: pihole (${currentUid} => ${PIHOLE_UID})"
            usermod -o -u ${PIHOLE_UID} pihole
        else
            echo "  [i] ID for user pihole is already ${PIHOLE_UID}, no need to change"
        fi
    else
        echo "  [i] PIHOLE_UID not set in environment, using default (${currentUid})"
    fi

    currentGid=$(id -g pihole)

    # If PIHOLE_GID is set, modify the pihole group's id to match
    if [ -n "${PIHOLE_GID}" ]; then
        if [[ ${currentGid} -ne ${PIHOLE_GID} ]]; then
            echo "  [i] Changing ID for group: pihole (${currentGid} => ${PIHOLE_GID})"
            groupmod -o -g ${PIHOLE_GID} pihole
        else
            echo "  [i] ID for group pihole is already ${PIHOLE_GID}, no need to change"
        fi
    else
        echo "  [i] PIHOLE_GID not set in environment, using default (${currentGid})"
    fi
    echo ""
}

install_additional_packages() {
    if [ -n "${ADDITIONAL_PACKAGES}" ]; then
        echo "  [i] Additional packages requested: ${ADDITIONAL_PACKAGES}"
        echo "  [i] Fetching APK repository metadata."
        if ! apk update; then
            echo "  [i] Failed to fetch APK repository metadata."
        else
            echo "  [i] Installing additional packages: ${ADDITIONAL_PACKAGES}."
            # shellcheck disable=SC2086
            if ! apk add --no-cache ${ADDITIONAL_PACKAGES}; then
                echo "  [i] Failed to install additional packages."
            fi
        fi
        echo ""
    fi
}

start_cron() {
    echo "  [i] Starting crond for scheduled scripts. Randomizing times for gravity and update checker"
    # Randomize gravity update time
    sed -i "s/59 1 /$((1 + RANDOM % 58)) $((3 + RANDOM % 2))/" /crontab.txt
    # Randomize update checker time
    sed -i "s/59 17/$((1 + RANDOM % 58)) $((12 + RANDOM % 8))/" /crontab.txt
    /usr/bin/crontab /crontab.txt

    /usr/sbin/crond
    echo ""
}

install_logrotate() {
    # Install the logrotate config file - this is done already in Dockerfile
    # but if a user has mounted a volume over /etc/pihole, it will have been lost
    # pihole-FTL-prestart.sh will set the ownership of the file to root:root
    echo "  [i] Ensuring logrotate script exists in /etc/pihole"
    install -Dm644 -t /etc/pihole /etc/.pihole/advanced/Templates/logrotate
    echo ""
}

migrate_gravity() {
    echo "  [i] Gravity migration checks"
    gravityDBfile=$(getFTLConfigValue files.gravity)

    if [[ -z "${PYTEST}" ]]; then
        if [[ ! -f /etc/pihole/adlists.list ]]; then
            echo "  [i] No adlist file found, creating one with a default blocklist"
            echo "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" >/etc/pihole/adlists.list
        fi
    fi

    if [ ! -f "${gravityDBfile}" ]; then
        echo "  [i] ${gravityDBfile} does not exist (Likely due to a fresh volume). This is a required file for Pi-hole to operate."
        echo "  [i] Gravity will now be run to create the database"
        pihole -g
    else
        echo "  [i] Existing gravity database found"
        # source the migration script and run the upgrade function
        source /etc/.pihole/advanced/Scripts/database_migration/gravity-db.sh
        upgrade_gravityDB "${gravityDBfile}" "/etc/pihole"
    fi
    echo ""
}

# shellcheck disable=SC2034
ftl_config() {

    # Force a check of pihole-FTL --config, this will read any environment variables and set them in the config file
    # suppress the output as we don't need to see the default values.
    getFTLConfigValue >/dev/null

    # If FTLCONF_files_macvendor is not set
    if [[ -z "${FTLCONF_files_macvendor:-}" ]]; then
        # User is not passing in a custom location - so force FTL to use the file we moved to / during the build
        setFTLConfigValue "files.macvendor" "/macvendor.db"
        chown pihole:pihole /macvendor.db
    fi

    # If getFTLConfigValue "dns.upstreams" returns [], default to Google's DNS server
    if [[ $(getFTLConfigValue "dns.upstreams") == "[]" ]]; then
        echo "  [i] No DNS upstream set in environment or config file, defaulting to Google DNS"
        setFTLConfigValue "dns.upstreams" "[\"8.8.8.8\", \"8.8.4.4\"]"
    fi

    setup_web_password
}

setup_web_password() {
    # If FTLCONF_webserver_api_password is not set
    if [ -z "${FTLCONF_webserver_api_password+x}" ]; then
        # Is this already set to something other than blank (default) in FTL's config file? (maybe in a volume mount)
        if [[ $(pihole-FTL --config webserver.api.pwhash) ]]; then
            echo "  [i] Password already set in config file"
            return
        else
            # If we are here, the password is set in neither the environment nor the config file
            # We will generate a random password.
            RANDOMPASSWORD=$(tr -dc _A-Z-a-z-0-9 </dev/urandom | head -c 8)
            echo "  [i] No password set in environment or config file, assigning random password: $RANDOMPASSWORD"

            # Explicitly turn off bash printing when working with secrets
            { set +x; } 2>/dev/null

            pihole-FTL --config webserver.api.password "$RANDOMPASSWORD" >/dev/null

            # To avoid printing this if conditional in bash debug, turn off  debug above..
            # then re-enable debug if necessary (more code but cleaner printed output)
            if [ "${PH_VERBOSE:-0}" -gt 0 ]; then
                set -x
            fi
        fi
    else
        echo "  [i] Assigning password defined by Environment Variable"
    fi
}

start_ftl() {

    echo "  [i] pihole-FTL pre-start checks"
    echo ""

    # Remove possible leftovers from previous pihole-FTL processes
    rm -f /dev/shm/FTL-* 2>/dev/null
    rm -f /run/pihole/FTL.sock

    # Is /var/run/pihole used anymore? Or is this just a hangover from old container version
    # /var/log sorted by running pihole-FTL-prestart.sh
    # mkdir -p /var/run/pihole /var/log/pihole
    # touch /var/log/pihole/FTL.log /var/log/pihole/pihole.log
    # chown -R pihole:pihole /var/run/pihole /var/log/pihole /etc/pihole

    fix_capabilities
    sh /opt/pihole/pihole-FTL-prestart.sh

    echo "  [i] Starting pihole-FTL ($FTL_CMD) as ${DNSMASQ_USER}"
    capsh --user=$DNSMASQ_USER --keep=1 -- -c "/usr/bin/pihole-FTL $FTL_CMD >/dev/null" &
    echo ""

    # Notes on above:
    # - DNSMASQ_USER default of pihole is in Dockerfile & can be overwritten by runtime container env
    # - /var/log/pihole/pihole*.log has FTL's output that no-daemon would normally print in FG too
    #   prevent duplicating it in docker logs by sending to dev null
}

fix_capabilities() {
    # Testing on Docker 20.10.14 with no caps set shows the following caps available to the container:
    # Current: cap_chown,cap_dac_override,cap_fowner,cap_fsetid,cap_kill,cap_setgid,cap_setuid,cap_setpcap,cap_net_bind_service,cap_net_raw,cap_sys_chroot,cap_mknod,cap_audit_write,cap_setfcap=ep
    # FTL can also use CAP_NET_ADMIN and CAP_SYS_NICE. If we try to set them when they haven't been explicitly enabled, FTL will not start. Test for them first:
    echo "  [i] Setting capabilities on pihole-FTL where possible"
    capsh --has-p=cap_chown 2>/dev/null && CAP_STR+=',CAP_CHOWN'
    capsh --has-p=cap_net_bind_service 2>/dev/null && CAP_STR+=',CAP_NET_BIND_SERVICE'
    capsh --has-p=cap_net_raw 2>/dev/null && CAP_STR+=',CAP_NET_RAW'
    capsh --has-p=cap_net_admin 2>/dev/null && CAP_STR+=',CAP_NET_ADMIN' || DHCP_READY='false'
    capsh --has-p=cap_sys_nice 2>/dev/null && CAP_STR+=',CAP_SYS_NICE'
    capsh --has-p=cap_sys_time 2>/dev/null && CAP_STR+=',CAP_SYS_TIME'

    if [[ ${CAP_STR} ]]; then
        # We have the (some of) the above caps available to us - apply them to pihole-FTL
        echo "  [i] Applying the following caps to pihole-FTL:"
        IFS=',' read -ra CAPS <<<"${CAP_STR:1}"
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
    echo ""
}
