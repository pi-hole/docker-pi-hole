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

apt-get -y build-dep pam
export CONFIGURE_OPTS=--disable-audit
cd /tmp
apt-get -b source pam
dpkg -i libpam-doc*.deb libpam-modules*.deb libpam-runtime*.deb libpam0g*.deb
rm -rf /tmp/*

apt-get install -y curl procps
curl -L -s $S6OVERLAY_RELEASE | tar xvzf - -C /
mv /init /s6-init
