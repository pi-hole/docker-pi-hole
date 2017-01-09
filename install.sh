#!/bin/bash -x
mkdir -p /etc/pihole/

#     Make pihole scripts fail searching for `systemctl`,
# which fails pretty miserably in docker compared to `service`
# For more info see docker/docker issue #7459
mv `which systemctl` /bin/no_systemctl && \
# debconf-apt-progress seems to hang so get rid of it too
mv `which debconf-apt-progress` /bin/no_debconf-apt-progress

# Get the install functions
wget -O "$PIHOLE_INSTALL" https://install.pi-hole.net
if [[ "$IMAGE" == 'alpine' ]] ; then
    sed -i '/OS distribution not supported/ i\  echo "Hi Alpine"' "$PIHOLE_INSTALL"
    sed -i '/OS distribution not supported/,+1d' "$PIHOLE_INSTALL"
    sed -i 's#nologin pihole#nologin pihole 2>/dev/null || adduser -S -s /sbin/nologin pihole#g' "$PIHOLE_INSTALL"
    sed -i '/usermod -a -G/ s#$# 2> /dev/null || addgroup pihole ${LIGHTTPD_GROUP}#g' "$PIHOLE_INSTALL"
    sed -i 's/www-data/nginx/g' "$PIHOLE_INSTALL"
    sed -i '/LIGHTTPD_CFG/d' "${PIHOLE_INSTALL}"
    sed -i '/etc\/cron.d\//d' "${PIHOLE_INSTALL}"
    LIGHTTPD_USER="nginx"
    LIGHTTPD_GROUP="nginx"

fi
PH_TEST=true . "${PIHOLE_INSTALL}"

# Run only what we need from installer
export USER=pihole
if [[ "$IMAGE" == 'debian' ]] ; then
    install_dependent_packages INSTALLER_DEPS[@]
    install_dependent_packages PIHOLE_DEPS[@]
elif [[ "$IMAGE" == 'alpine' ]] ; then
    apk add \
        dnsmasq \
        nginx \
        ca-certificates \
        php5-fpm php5-json php5-openssl libxml2 \
        bc bash curl perl sudo git
fi
git clone --depth 1 ${piholeGitUrl} ${PI_HOLE_LOCAL_REPO} 
git clone --depth 1 ${webInterfaceGitUrl} ${webInterfaceDir}

export PIHOLE_INTERFACE=eth0
export IPV4_ADDRESS=0.0.0.0
export IPV6_ADDRESS=0:0:0:0:0:0
export PIHOLE_DNS_1=8.8.8.8
export PIHOLE_DNS_2=8.8.4.4
export QUERY_LOGGING=true
installPihole | tee "${tmpLog}"

mv "${tmpLog}" "${instalLogLoc}"

# Fix dnsmasq in docker
grep -q '^user=root' || echo -e '\nuser=root' >> /etc/dnsmasq.conf 
echo done
