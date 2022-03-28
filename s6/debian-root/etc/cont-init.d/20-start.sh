#!/usr/bin/with-contenv bash
set -e

bashCmd='bash -e'
if [ "${PH_VERBOSE:-0}" -gt 0 ] ; then
    set -x ;
    bashCmd='bash -e -x'
fi

$bashCmd /start.sh
# Gotta go fast, no time for gravity
if [ -n "$PYTEST" ]; then
    sed -i 's/^gravity_spinup$/#gravity_spinup # DISABLED FOR PYTEST/g' "$(which gravity.sh)"
fi

gravityDBfile="/etc/pihole/gravity.db"
config_file="/etc/pihole/pihole-FTL.conf"
# make a point to mention which config file we're checking, as breadcrumb to revisit if/when pihole-FTL.conf is succeeded by TOML
echo "  Checking if custom gravity.db is set in ${config_file}"
if [[ -f "${config_file}" ]]; then
    gravityDBfile="$(grep --color=never -Po "^GRAVITYDB=\K.*" "${config_file}" 2> /dev/null || echo "/etc/pihole/gravity.db")"
fi


if [ -z "$SKIPGRAVITYONBOOT" ] || [ ! -e "${gravityDBfile}" ]; then
    if [ -n "$SKIPGRAVITYONBOOT" ];then
        echo "  SKIPGRAVITYONBOOT is set, however ${gravityDBfile} does not exist (Likely due to a fresh volume). This is a required file for Pi-hole to operate."
        echo "  Ignoring SKIPGRAVITYONBOOT on this occaision."
    fi

    echo '@reboot root PATH="$PATH:/usr/sbin:/usr/local/bin/" pihole updateGravity >/var/log/pihole_updateGravity.log || cat /var/log/pihole_updateGravity.log' > /etc/cron.d/gravity-on-boot
else
    echo "  Skipping Gravity Database Update."
    [ ! -e /etc/cron.d/gravity-on-boot ] || rm /etc/cron.d/gravity-on-boot &>/dev/null
fi

pihole -v

# generate default certificate if needed
if [ ! -e /etc/lighttpd/server.pem ]; then
  echo "Generating a ssl certificate for lighttpd."
  openssl req -x509 -newkey rsa:4096 -nodes -keyout /etc/lighttpd/key.pem -out /etc/lighttpd/certificate.pem -sha256 -days 3650 -subj "/C=US/ST=Oregon/L=Portland/O=Company Name/OU=Org/CN=www.example.com"
  cat /etc/lighttpd/certificate.pem /etc/lighttpd/key.pem > /etc/lighttpd/server.pem
  chown -R www-data:www-data /etc/lighttpd
  chmod 0600 /etc/lighttpd/*.pem
fi

echo "  Container tag is: ${PIHOLE_DOCKER_TAG}"