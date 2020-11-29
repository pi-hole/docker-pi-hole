#!/bin/bash -ex

mkdir -p /etc/pihole/
mkdir -p /var/run/pihole
# Production tags with valid web footers
export CORE_VERSION="$(cat /etc/docker-pi-hole-version)"
export WEB_VERSION="${CORE_VERSION}"
export PIHOLE_SKIP_OS_CHECK=true
# Overwrite WEB_VERSION if core and web versions are different
#export WEB_VERSION="v5.1.1"

# Only use for pre-production / testing
export CHECKOUT_BRANCHES=false
# Search for release/* branch naming convention for custom checkouts
if [[ "$CORE_VERSION" == *"release/"* ]] ; then
    CHECKOUT_BRANCHES=true
fi

apt-get update
apt-get install --no-install-recommends -y curl procps ca-certificates
# curl in armhf-buster's image has SSL issues. Running c_rehash fixes it.
# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=923479
c_rehash
ln -s `which echo` /usr/local/bin/whiptail
curl -L -s $S6OVERLAY_RELEASE | tar xvzf - -C /
mv /init /s6-init

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

ln -s /bin/true /usr/local/bin/service
bash -ex "./${PIHOLE_INSTALL}" --unattended
rm /usr/local/bin/service

# IPv6 support for nc openbsd better than traditional
apt-get install -y --force-yes netcat-openbsd

fetch_release_metadata() {
    local directory="$1"
    local version="$2"
    pushd "$directory"
    git fetch -t
    git remote set-branches origin '*'
    git fetch --depth 10
    git checkout master
    git reset --hard "$version"
    popd
}

if [[ $CHECKOUT_BRANCHES == true ]] ; then
    ln -s /bin/true /usr/local/bin/service
    ln -s /bin/true /usr/local/bin/update-rc.d
    echo "${CORE_VERSION}" | sudo tee /etc/pihole/ftlbranch
    echo y | bash -x pihole checkout core ${CORE_VERSION}
    echo y | bash -x pihole checkout web ${WEB_VERSION}
    # echo y | bash -x pihole checkout ftl ${CORE_VERSION}
    # If the v is forgotten: ${CORE_VERSION/v/}
    unlink /usr/local/bin/service
    unlink /usr/local/bin/update-rc.d
else
    # Reset to our tags so version numbers get detected correctly
    fetch_release_metadata "${PI_HOLE_LOCAL_REPO}" "${CORE_VERSION}"
    fetch_release_metadata "${webInterfaceDir}" "${WEB_VERSION}"
fi

# FTL Armel fix not in prod yet
# Remove once https://github.com/pi-hole/pi-hole/commit/3fbb0ac8dde14b8edc1982ae3a2a021f3cf68477 is in master
if [[ "$ARCH" == 'armel' ]]; then
    curl -o /usr/bin/pihole-FTL https://ftl.pi-hole.net/development/pihole-FTL-armel-native
fi

sed -i 's/readonly //g' /opt/pihole/webpage.sh
sed -i '/^WEBPASSWORD/d' /etc/pihole/setupVars.conf

# Replace the call to `updatePiholeFunc` in arg parse with new `unsupportedFunc`
sed -i $'s/helpFunc() {/unsupportedFunc() {\\\n  echo "Function not supported in Docker images"\\\n  exit 0\\\n}\\\n\\\nhelpFunc() {/g' /usr/local/bin/pihole
sed -i $'s/)\s*updatePiholeFunc/) unsupportedFunc/g' /usr/local/bin/pihole

touch /.piholeFirstBoot

echo 'Docker install successful'
