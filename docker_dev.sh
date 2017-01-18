#!/bin/bash -e
docker build -f alpine.docker -t diginc/pi-hole:alpine .
docker tag diginc/pi-hole:alpine diginc/pi-hole:latest
docker build -f debian.docker -t diginc/pi-hole:debian .

IP_LOOKUP="$(ip route get 8.8.8.8 | awk '{ print $NF; exit }')"  # May not work for VPN / tun0
IP="${IP:-$IP_LOOKUP}"  # use $IP, if set, otherwise IP_LOOKUP

# Alternative ports to not conflict with my real instance
# shellcheck disable=SC2068
docker run -it --rm --cap-add=NET_ADMIN \
  -p 5053:53/tcp \
  -p 5053:53/udp \
  -p 5080:80 \
  -e ServerIP="$IP" \
  -e VIRTUAL_HOST='pihole.diginc.lan:5080' \
  $@ \
  diginc/pi-hole:"${image:-alpine}"
