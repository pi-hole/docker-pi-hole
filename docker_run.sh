#!/bin/bash

IP=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
docker run -p 53:53/tcp -p 53:53/udp -p 80:80 --cap-add=NET_ADMIN -e piholeIP="$IP" --name pihole -d dockerhole_alpine
