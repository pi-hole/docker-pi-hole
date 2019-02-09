#!/bin/bash -ex

mkdir -p /etc/pihole/
mkdir -p /var/run/pihole
# Production tags with valid web footers
export CORE_TAG="$(cat /etc/docker-pi-hole-version)"
# 4.2.1 -> 4.2 since no patch release for web
export WEB_TAG="${CORE_TAG/.1/}"
# Only use for pre-production / testing
export USE_CUSTOM_BRANCHES=false

apt-get update
apt-get install -y curl procps
curl -L -s $S6OVERLAY_RELEASE | tar xvzf - -C /
mv /init /s6-init

if [[ $USE_CUSTOM_BRANCHES == true ]] ; then
    CORE_TAG="release/$(cat /etc/docker-pi-hole-version)"
fi

# debconf-apt-progress seems to hang so get rid of it too
which debconf-apt-progress
mv "$(which debconf-apt-progress)" /bin/no_debconf-apt-progress

# Get the install functions
curl https://raw.githubusercontent.com/pi-hole/pi-hole/${CORE_TAG}/automated%20install/basic-install.sh > "$PIHOLE_INSTALL" 
PH_TEST=true . "${PIHOLE_INSTALL}"

# Preseed variables to assist with using --unattended install
{
  echo "PIHOLE_INTERFACE=eth0"
  echo "IPV4_ADDRESS=0.0.0.0"
  echo "IPV6_ADDRESS=0:0:0:0:0:0"
  echo "PIHOLE_DNS_1=8.8.8.8"
  echo "PIHOLE_DNS_2=8.8.4.4"
  echo "QUERY_LOGGING=true"
  echo "INSTALL_WEB_SERVER=true"
  echo "INSTALL_WEB_INTERFACE=true"
  echo "LIGHTTPD_ENABLED=true"
}>> "${setupVars}"
source $setupVars

export USER=pihole
distro_check

# fix permission denied to resolvconf post-inst /etc/resolv.conf moby/moby issue #1297
apt-get -y install debconf-utils
echo resolvconf resolvconf/linkify-resolvconf boolean false | debconf-set-selections

# Tried this - unattended causes starting services during a build, should probably PR a flag to shut that off and switch to that 
#bash -ex "./${PIHOLE_INSTALL}" --unattended
install_dependent_packages INSTALLER_DEPS[@]
install_dependent_packages PIHOLE_DEPS[@]
install_dependent_packages PIHOLE_WEB_DEPS[@]
# IPv6 support for nc openbsd better than traditional
apt-get install -y --force-yes netcat-openbsd

piholeGitUrl="${piholeGitUrl}"
webInterfaceGitUrl="${webInterfaceGitUrl}"
webInterfaceDir="${webInterfaceDir}"
git clone "${piholeGitUrl}" "${PI_HOLE_LOCAL_REPO}"
git clone "${webInterfaceGitUrl}" "${webInterfaceDir}"

tmpLog="/tmp/pihole-install.log"
installLogLoc="${installLogLoc}"
FTLdetect 2>&1 | tee "${tmpLog}"
installPihole 2>&1 | tee "${tmpLog}"
mv "${tmpLog}" /

if [[ $USE_CUSTOM_BRANCHES == true ]] ; then
    ln -s /bin/true /usr/local/bin/service
    ln -s /bin/true /usr/local/bin/update-rc.d
    echo y | bash -x pihole checkout core ${CORE_TAG}
    echo y | bash -x pihole checkout web ${CORE_TAG}
    echo y | bash -x pihole checkout ftl ${CORE_TAG}
    # If the v is forgotten: ${CORE_TAG/v/}
    unlink /usr/local/bin/service
    unlink /usr/local/bin/update-rc.d
else
    # Reset to our tags so version numbers get detected correctly
    pushd "${PI_HOLE_LOCAL_REPO}"; git reset --hard "${CORE_TAG}"; popd;
    pushd "${webInterfaceDir}"; git reset --hard "${WEB_TAG}"; popd;
fi

sed -i 's/readonly //g' /opt/pihole/webpage.sh

# Replace the call to `updatePiholeFunc` in arg parse with new `unsupportedFunc`
sed -i $'s/helpFunc() {/unsupportedFunc() {\\\n  echo "Function not supported in Docker images"\\\n  exit 0\\\n}\\\n\\\nhelpFunc() {/g' /usr/local/bin/pihole
sed -i $'s/)\s*updatePiholeFunc/) unsupportedFunc/g' /usr/local/bin/pihole

touch /.piholeFirstBoot

echo 'Docker install successful'
