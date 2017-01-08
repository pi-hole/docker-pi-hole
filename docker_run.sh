#!/bin/bash
IMAGE=${1:-'diginc/pi-hole:alpine'}
IP=$(ip route get 8.8.8.8 | awk '{ print $NF; exit }')

# Default ports + daemonized docker container
docker run -p 53:53/tcp -p 53:53/udp -p 80:80 \
  --cap-add=NET_ADMIN \
  -e ServerIP="$IP" \
  --name pihole \
  -d "$IMAGE"
