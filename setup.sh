#!/bin/bash -ex
# Seperated specifically to enable easy modificaiton of Dockerfile to cache this really long step

# https://github.com/pi-hole/docker-pi-hole/issues/243
# fix error AUDIT: Allow login in non-init namespaces
# Credit to https://github.com/sequenceiq/docker-pam/blob/master/ubuntu-14.04/Dockerfile
srclist="/etc/apt/sources.list"
cat $srclist | while read line; do
  srcline="$(echo $line | sed 's/deb/deb-src/')"
  echo "$srcline" >> $srclist
done;

apt-get update

cd /tmp
apt-get -s -y build-dep pam > builddeps.txt
apt-get -y build-dep pam

export CONFIGURE_OPTS=--disable-audit
apt-get -b source pam
#dpkg -i libpam-doc*.deb libpam-modules*.deb libpam-runtime*.deb libpam0g*.deb
# Cleanup
apt-get purge -y build-essential $(grep '^Inst' builddeps.txt | awk '{ print $2 }' | tr '\n' ' ')
apt-get autoremove -y
rm -rf /tmp/*

# Install s6
apt-get install -y curl procps
curl -L -s $S6OVERLAY_RELEASE | tar xvzf - -C /
mv /init /s6-init
