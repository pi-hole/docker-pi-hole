#!/bin/bash
IMAGE=${1:-'diginc/pi-hole:alpine'}
IP_LOOKUP="$(ip route get 8.8.8.8 | awk '{ print $NF; exit }')"  # May not work for VPN / tun0
IPv6_LOOKUP="$(ip -6 route get 2001:4860:4860::8888 | awk '{ print $10; exit }')"  # May not work for VPN / tun0
IP="${IP:-$IP_LOOKUP}"  # use $IP, if set, otherwise IP_LOOKUP
IPv6="${IPv6:-$IPv6_LOOKUP}"  # use $IPv6, if set, otherwise IP_LOOKUP

echo "IP: ${IP} - IPv6: ${IPv6}"

# Default ports + daemonized docker container
docker create \
    --name pihole \
    -p 53:53/tcp -p 53:53/udp -p 80:80 \
    -v /etc/volumes/pihole:/etc/pihole \
    -v /etc/volumes/dnsmasq.d:/etc/dnsmasq.d \
    -e ServerIP="${IP:-$(ip route get 8.8.8.8 | awk '{ print $NF; exit }')}" \
    -e ServerIPv6="${IPv6:-$(ip -6 route get 2001:4860:4860::8888 | awk '{ print $10; exit }')}" \
    --restart=always \
    diginc/pi-hole

docker start pihole
sleep 2
docker logs pihole 2> /dev/null | grep 'password:'
