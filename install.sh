#!/bin/bash -ex
mkdir -p /etc/pihole/
export CORE_TAG='v3.1.4'
export WEB_TAG='v3.1'
export FTL_TAG='v2.11.1'

#     Make pihole scripts fail searching for `systemctl`,
# which fails pretty miserably in docker compared to `service`
# For more info see docker/docker issue #7459
mv "$(which systemctl)" /bin/no_systemctl && \
# debconf-apt-progress seems to hang so get rid of it too
mv "$(which debconf-apt-progress)" /bin/no_debconf-apt-progress

# Get the install functions
wget -O "$PIHOLE_INSTALL" https://raw.githubusercontent.com/pi-hole/pi-hole/${CORE_TAG}/automated%20install/basic-install.sh
if [[ "$TAG" == 'alpine' ]] ; then
    sed -i '/OS distribution not supported/ i\  echo "Hi Alpine"' "$PIHOLE_INSTALL"
    sed -i '/OS distribution not supported/,+1d' "$PIHOLE_INSTALL"
    sed -i 's#nologin pihole#nologin pihole 2>/dev/null || adduser -S -s /sbin/nologin pihole#g' "$PIHOLE_INSTALL"
    # shellcheck disable=SC2016
    sed -i '/usermod -a -G/ s#$# 2> /dev/null || addgroup pihole ${LIGHTTPD_GROUP}#g' "$PIHOLE_INSTALL"
    sed -i 's/www-data/nginx/g' "$PIHOLE_INSTALL"
    sed -i '/LIGHTTPD_CFG/d' "${PIHOLE_INSTALL}"
    sed -i '/etc\/cron.d\//d' "${PIHOLE_INSTALL}"
    # For new FTL install lines
    sed -i 's/sha1sum --status --quiet/sha1sum -s/g' "${PIHOLE_INSTALL}"
    sed -i 's/install -T/install /g' "${PIHOLE_INSTALL}"
	# shellcheck disable=SC2016
	sed -i '/FTLinstall/ s/${binary}/pihole-FTL-musl-linux-x86_64/g' "${PIHOLE_INSTALL}"
    LIGHTTPD_USER="nginx" # shellcheck disable=SC2034
    LIGHTTPD_GROUP="nginx" # shellcheck disable=SC2034
    LIGHTTPD_CFG="lighttpd.conf.debian" # shellcheck disable=SC2034
    DNSMASQ_USER="dnsmasq" # shellcheck disable=SC2034
fi
PH_TEST=true . "${PIHOLE_INSTALL}"

# Run only what we need from installer
export USER=pihole
if [[ "$TAG" == 'debian' ]] ; then
    distro_check
    install_dependent_packages INSTALLER_DEPS[@]
    install_dependent_packages PIHOLE_DEPS[@]
    install_dependent_packages PIHOLE_WEB_DEPS[@]
    sed -i "/sleep 2/ d" /etc/init.d/dnsmasq # SLOW
	# IPv6 support for nc openbsd better than traditional
	apt-get install -y --force-yes netcat-openbsd
elif [[ "$TAG" == 'alpine' ]] ; then
    apk add \
        dnsmasq \
        nginx \
        ca-certificates \
        php5-fpm php5-json php5-openssl php5-zip php5-sockets libxml2 \
        bc bash curl perl sudo git
    # S6 service like to be blocking/foreground
    sed -i 's|^;daemonize = yes|daemonize = no|' /etc/php5/php-fpm.conf
fi

piholeGitUrl="${piholeGitUrl}"
webInterfaceGitUrl="${webInterfaceGitUrl}"
webInterfaceDir="${webInterfaceDir}"
git clone "${piholeGitUrl}" "${PI_HOLE_LOCAL_REPO}"
pushd "${PI_HOLE_LOCAL_REPO}"; git reset --hard "${CORE_TAG}"; popd;
git clone "${webInterfaceGitUrl}" "${webInterfaceDir}"
pushd "${webInterfaceDir}"; git reset --hard "${WEB_TAG}"; popd;

export PIHOLE_INTERFACE=eth0
export IPV4_ADDRESS=0.0.0.0
export IPV6_ADDRESS=0:0:0:0:0:0
export PIHOLE_DNS_1=8.8.8.8
export PIHOLE_DNS_2=8.8.4.4
export QUERY_LOGGING=true

tmpLog="${tmpLog}"
instalLogLoc="${instalLogLoc}"
installPihole | tee "${tmpLog}"
sed -i 's/readonly //g' /opt/pihole/webpage.sh
if [[ "$TAG" == 'alpine' ]] ; then
    cp /etc/.pihole/advanced/pihole.cron /etc/crontabs/pihole

    # More chewing gum patching, post installPihole dnsmasq replacement seems to work probably due to dnsmasq uid missing
    apk del dnsmasq && apk add dnsmasq-dnssec
	
    # Fix hostname bug on block page
    sed -i "s/\$_SERVER\['SERVER_NAME'\]/\$_SERVER\['HTTP_HOST'\]/" /var/www/html/pihole/index.php
fi
 
mv "${tmpLog}" "${instalLogLoc}"
touch /.piholeFirstBoot

# Fix dnsmasq in docker
grep -q '^user=root' || echo -e '\nuser=root' >> /etc/dnsmasq.conf 
echo 'Docker install successful'
