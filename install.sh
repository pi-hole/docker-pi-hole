#!/bin/bash -ex

mkdir -p /etc/pihole/
mkdir -p /var/run/pihole
# Production tags with valid web footers
export CORE_VERSION="$(cat /etc/docker-pi-hole-version)"
# Major.Minor for web tag until patches are released for it
export WEB_VERSION="$(echo ${CORE_VERSION} | grep -Po "v\d+\.\d+")"
# Only use for pre-production / testing
export USE_CUSTOM_BRANCHES=false

apt-get update
apt-get install -y curl procps
curl -L -s $S6OVERLAY_RELEASE | tar xvzf - -C /
mv /init /s6-init

if [[ $USE_CUSTOM_BRANCHES == true ]] ; then
    CORE_VERSION="hotfix/${CORE_VERSION}"
    WEB_VERSION="release/v4.2"
fi

# debconf-apt-progress seems to hang so get rid of it too
which debconf-apt-progress
mv "$(which debconf-apt-progress)" /bin/no_debconf-apt-progress

# Get the install functions
curl https://raw.githubusercontent.com/pi-hole/pi-hole/${CORE_VERSION}/automated%20install/basic-install.sh > "$PIHOLE_INSTALL" 
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
    echo y | bash -x pihole checkout core ${CORE_VERSION}
    echo y | bash -x pihole checkout web ${WEB_VERSION}
    echo y | bash -x pihole checkout ftl tweak/overhaul_overTime
    # If the v is forgotten: ${CORE_VERSION/v/}
    unlink /usr/local/bin/service
    unlink /usr/local/bin/update-rc.d
else
    # Reset to our tags so version numbers get detected correctly
    pushd "${PI_HOLE_LOCAL_REPO}"; git reset --hard "${CORE_VERSION}"; popd;
    pushd "${webInterfaceDir}"; git reset --hard "${WEB_VERSION}"; popd;
fi

sed -i 's/readonly //g' /opt/pihole/webpage.sh
sed -i '/^WEBPASSWORD/d' /etc/pihole/setupVars.conf

# Replace the call to `updatePiholeFunc` in arg parse with new `unsupportedFunc`
sed -i $'s/helpFunc() {/unsupportedFunc() {\\\n  echo "Function not supported in Docker images"\\\n  exit 0\\\n}\\\n\\\nhelpFunc() {/g' /usr/local/bin/pihole
sed -i $'s/)\s*updatePiholeFunc/) unsupportedFunc/g' /usr/local/bin/pihole

touch /.piholeFirstBoot

echo 'Docker install successful'
