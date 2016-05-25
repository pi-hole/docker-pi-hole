#!/bin/bash -e
docker build -f alpine.docker -t diginc/pi-hole:alpine .
docker tag diginc/pi-hole:alpine diginc/pi-hole:latest
docker build -f debian.docker -t diginc/pi-hole:debian .

IP=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)

# Alternative ports to not conflict with my real instance
docker run -it --rm --cap-add=NET_ADMIN \
  -p 5053:53/tcp \
  -p 5053:53/udp \
  -p 5080:80 \
  -e ServerIP="$IP" \
  $@ \
  diginc/pi-hole:${image:-alpine}
