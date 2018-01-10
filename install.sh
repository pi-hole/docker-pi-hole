#!/bin/bash -ex
mkdir -p /etc/pihole/
export CORE_TAG='v3.2.1'
export WEB_TAG='v3.2.1'
export FTL_TAG='v2.13.2'
export USE_DEVELOPMENT_BRANCHES=true

#     Make pihole scripts fail searching for `systemctl`,
# which fails pretty miserably in docker compared to `service`
# For more info see docker/docker issue #7459
mv "$(which systemctl)" /bin/no_systemctl && \
# debconf-apt-progress seems to hang so get rid of it too
mv "$(which debconf-apt-progress)" /bin/no_debconf-apt-progress

# Get the install functions
CUSTOM_INSTALL='development'
wget -O "$PIHOLE_INSTALL" https://raw.githubusercontent.com/pi-hole/pi-hole/${CUSTOM_INSTALL:-$CORE_TAG}/automated%20install/basic-install.sh
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
fi

piholeGitUrl="${piholeGitUrl}"
webInterfaceGitUrl="${webInterfaceGitUrl}"
webInterfaceDir="${webInterfaceDir}"
git clone "${piholeGitUrl}" "${PI_HOLE_LOCAL_REPO}"
git clone "${webInterfaceGitUrl}" "${webInterfaceDir}"
if [[ $USE_DEVELOPMENT_BRANCHES == true ]] ; then
    pushd "${PI_HOLE_LOCAL_REPO}"; git checkout development; popd;
    pushd "${webInterfaceDir}"; git checkout devel; popd;
else
    pushd "${PI_HOLE_LOCAL_REPO}"; 
    git reset --hard "${CORE_TAG}"; 
    popd;
    pushd "${webInterfaceDir}"; git reset --hard "${WEB_TAG}"; popd;
fi

export PIHOLE_INTERFACE=eth0
export IPV4_ADDRESS=0.0.0.0
export IPV6_ADDRESS=0:0:0:0:0:0
export PIHOLE_DNS_1=8.8.8.8
export PIHOLE_DNS_2=8.8.4.4
export QUERY_LOGGING=true

tmpLog="/tmp/pihole-install.log"
installLogLoc="${installLogLoc}"
installPihole | tee "${tmpLog}"
sed -i 's/readonly //g' /opt/pihole/webpage.sh

sed -i $'s/helpFunc() {/unsupportedFunc() {\\\n  echo "Function not supported in Docker images"\\\n  exit 0\\\n}\\\n\\\nhelpFunc() {/g' /usr/local/bin/pihole
# Replace references to `updatePiholeFunc` with new `unsupportedFunc`
sed -i $'s/updatePiholeFunc;;/unsupportedFunc;;/g' /usr/local/bin/pihole

mv "${tmpLog}" "${instalLogLoc}"
touch /.piholeFirstBoot

# Fix dnsmasq in docker
grep -q '^user=root' || echo -e '\nuser=root' >> /etc/dnsmasq.conf 
echo 'Docker install successful'
