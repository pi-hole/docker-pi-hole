#!/bin/bash -ex

mkdir -p /etc/pihole/
mkdir -p /var/run/pihole

CORE_LOCAL_REPO=/etc/.pihole
WEB_LOCAL_REPO=/var/www/html/admin

setupVars=/etc/pihole/setupVars.conf

s6_download_url() {
  DETECTED_ARCH=$(dpkg --print-architecture)
  S6_ARCH=$DETECTED_ARCH
  case $DETECTED_ARCH in
  armel)
    S6_ARCH="arm";;
  armhf)
    S6_ARCH="arm";;
  arm64)
    S6_ARCH="aarch64";;
  i386)
    S6_ARCH="x86";;
  ppc64el)
    S6_ARCH="ppc64le";;
esac
  echo "https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.gz"
}

ln -s `which echo` /usr/local/bin/whiptail
curl -L -s "$(s6_download_url)" | tar xvzf - -C /
mv /init /s6-init

# Preseed variables to assist with using --unattended install
{
  echo "PIHOLE_INTERFACE=eth0"
  echo "IPV4_ADDRESS=0.0.0.0"
  echo "IPV6_ADDRESS=0:0:0:0:0:0"
  echo "PIHOLE_DNS_1=8.8.8.8"
  echo "QUERY_LOGGING=true"
  echo "INSTALL_WEB_SERVER=true"
  echo "INSTALL_WEB_INTERFACE=true"
  echo "LIGHTTPD_ENABLED=true"
}>> "${setupVars}"
source $setupVars

export USER=pihole

export PIHOLE_SKIP_OS_CHECK=true

# Run the installer in unattended mode using the preseeded variables above and --reconfigure so that local repos are not updated
curl -sSL https://install.pi-hole.net | bash -sex -- --unattended

# At this stage, if we are building a :nightly tag, then switch the Pi-hole install to dev versions
if [[ "${PIHOLE_DOCKER_TAG}" = 'nightly'  ]]; then
  yes | pihole checkout dev
fi

sed -i 's/readonly //g' /opt/pihole/webpage.sh
sed -i '/^WEBPASSWORD/d' /etc/pihole/setupVars.conf

# sed a new function into the `pihole` script just above the `helpFunc()` function for later use.
sed -i $'s/helpFunc() {/unsupportedFunc() {\\\n  echo "Function not supported in Docker images"\\\n  exit 0\\\n}\\\n\\\nhelpFunc() {/g' /usr/local/bin/pihole

# Replace a few of the `pihole` options with calls to `unsupportedFunc`:
# pihole -up / pihole updatePihole
sed -i $'s/)\s*updatePiholeFunc/) unsupportedFunc/g' /usr/local/bin/pihole
# pihole uninstall
sed -i $'s/)\s*uninstallFunc/) unsupportedFunc/g' /usr/local/bin/pihole
# pihole -r / pihole reconfigure
sed -i $'s/)\s*reconfigurePiholeFunc/) unsupportedFunc/g' /usr/local/bin/pihole

if [[ "${PIHOLE_DOCKER_TAG}" != "dev" && "${PIHOLE_DOCKER_TAG}" != "nightly" ]]; then
  # If we are on a version other than dev or nightly, disable `pihole checkout`, otherwise it is useful to have for quick troubleshooting sometimes
  sed -i $'s/)\s*piholeCheckoutFunc/) unsupportedFunc/g' /usr/local/bin/pihole
fi

touch /.piholeFirstBoot

echo 'Docker install successful'