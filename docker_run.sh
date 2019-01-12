#!/bin/bash -e
# Lookups may not work for VPN / tun0
IP_LOOKUP="$(ip route get 8.8.8.8 | awk '{for(i=1;i<=NF;i++) if ($i=="src") print $(i+1)}')"
IPv6_LOOKUP="$(ip -6 route get 2001:4860:4860::8888 | awk '{for(i=1;i<=NF;i++) if ($i=="src") print $(i+1)}')"

# Just hard code these to your docker server's LAN IP if lookups aren't working
IP="${IP:-$IP_LOOKUP}"  # use $IP, if set, otherwise IP_LOOKUP
IPv6="${IPv6:-$IPv6_LOOKUP}"  # use $IPv6, if set, otherwise IP_LOOKUP

# Default of directory you run this from, update to where ever.
DOCKER_CONFIGS="$(pwd)"

echo -e "### Make sure your IPs are correct, hard code ServerIP ENV VARs if necessary\nIP: ${IP}\nIPv6: ${IPv6}"

# Default ports + daemonized docker container
docker run -d \
    --name pihole \
    -p 53:53/tcp -p 53:53/udp \
    -p 80:80 \
    -p 443:443 \
    `# The 2 arguments below are required if Pi-hole is to provide DHCP:` \
    `# --net=host` \
    `# --cap-add=NET_ADMIN` \
    -v "${DOCKER_CONFIGS}/pihole/:/etc/pihole/" \
    -v "${DOCKER_CONFIGS}/dnsmasq.d/:/etc/dnsmasq.d/" \
    -e ServerIP="${IP}" \
    -e ServerIPv6="${IPv6}" \
    --restart=unless-stopped \
    --dns=127.0.0.1 --dns=1.1.1.1 \
    pihole/pihole:latest


printf 'Starting up pihole container'
while [ "$(docker inspect -f "{{.State.Health.Status}}" pihole)" != "healthy" ]; do
    sleep 1
    printf '.'
done;

echo -e "\n$(docker logs pihole 2> /dev/null | grep 'password:') for your pi-hole: https://${IP}/admin/"
