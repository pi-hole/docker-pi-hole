#!/bin/bash -e
docker build -f alpine.docker -t dockerpihole_alpine .
docker build -f debian.docker -t dockerpihole_debian .

IP=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)

docker run -it --rm --cap-add=NET_ADMIN \
  -p 5053:53/tcp \
  -p 5053:53/udp \
  -p 5080:80 \
  -e ServerIP="$IP" \
  $@ \
  dockerpihole_${image:-alpine}
