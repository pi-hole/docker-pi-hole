#!/bin/bash
IMAGE=${1:-'diginc/pi-hole:alpine'}
IP_LOOKUP="$(ip route get 8.8.8.8 | awk '{ print $NF; exit }')"  # May not work for VPN / tun0
IP="${IP:-$IP_LOOKUP}"  # use $IP, if set, otherwise IP_LOOKUP

# Default ports + daemonized docker container
docker run -p 53:53/tcp -p 53:53/udp -p 80:80 \
  --cap-add=NET_ADMIN \
  -e ServerIP="$IP" \
  --name pihole \
  --restart=always \
  -d "$IMAGE"
