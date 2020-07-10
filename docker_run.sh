#!/usr/bin/env zsh
[ -z ${Pihole_Version+x} ] && Pihole_Version='latest'
SRC_Docker_image_base="pihole/pihole"
SRC_Docker_Image="${SRC_Docker_image_base}:${Pihole_Version}"
update_detected="no"
TZ="America/Chicago"

echo -e "\\nPihole-docker - Welcome to the startup/setup script."

exit_state() {
    if [[ $? != 0 ]]; then
        echo "Pihole-docker - Something when wrong with \"$1\"..."
        echo "Aborting."
        docker rm -f Pihole-docker-copy &> /dev/null
        exit 42
    fi
}

clear_service_container() {
    docker stop pihole &> /dev/null
    docker rm pihole &> /dev/null
}

Normal_docker_start() {
    echo -e "Pihole-docker - Starting service\\n"
    clear_service_container
    docker run \
        --privileged \
        --init \
        -p 53:53/tcp -p 53:53/udp \
        -p 80:80 \
        -p 443:443 \
        -e TZ="${TZ}" \
        -v "$(pwd)/etc-pihole/:/etc/pihole/" \
        -v "$(pwd)/etc-dnsmasq.d/:/etc/dnsmasq.d/" \
        --dns=127.0.0.1 --dns=1.1.1.1 \
        --restart=unless-stopped \
        --hostname pi.hole \
        -e VIRTUAL_HOST="pi.hole" \
        -e PROXY_LOCATION="pi.hole" \
        -e ServerIP="127.0.0.1" \
        --restart=unless-stopped \
        -d \
        --name pihole \
        ${SRC_Docker_Image}
    exit_state "Start service container"
}

update_container() {
    echo -e "Pihole-docker - Checking for updates\n"
    on_system_digests=$(docker images --digests | grep ${SRC_Docker_image_base} | grep $Pihole_Version | awk '{print $3}')
    latest_version_digets=$( docker pull ${SRC_Docker_Image} | grep Digest | awk '{print $2}' )
    if [[ "${latest_version_digets}" != "${on_system_digests}" ]]; then
      echo -e "Pihole-docker - Newer version of container detected.\n"
      echo -e "Pihole-docker - Now restarting service for changes to take affect."
      update_detected="yes"
    fi
}

ubuntu_disable_resolver() {
    echo "Pihole-docker - Removing system resolver"
    sed -r -i.orig 's/#?DNSStubListener=yes/DNSStubListener=no/g' /etc/systemd/resolved.conf
    sh -c 'rm /etc/resolv.conf && ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf'
    systemctl restart systemd-resolved
}
echo "Cheking if there is docker on system"
if [[ -z "$(which docker)" ]] ;then
    echo "Pihole-docker - We can't seem to find docker on the system :\\"
    echo "Pihole-docker - Make it so the \"which\" command can find it and run gain."
    echo "Pihole-docker - Goodbye for now..."
    exit 42
fi

l53="$(ss -nlpt | grep 53)"
if [[ $l53 == *"53"* && \
      $l53 != *"docker"* ]] ;then
    echo "Pihole-docker - Found open 53"
    if [[ "$(lsb_release -i | awk '{print $3}')" == "Ubuntu" ]]; then
        echo "Pihole-docker - This is an Ubuntu system"
        ubuntu_disable_resolver
    fi
fi

if [[ -z "$(docker ps -q -f name=pihole)" ]]; then
    Normal_docker_start
else
    echo -e "Pihole-docker - Service already running\n"
    update_container
    [[ "${update_detected}" == "yes" ]] && Normal_docker_start
fi
docker ps -f name=pihole ; exit_state "Finding the service profile in docker ps"
echo "Waiting for service to become healthey"
for i in $(seq 1 20); do
    if [ "$(docker inspect -f "{{.State.Health.Status}}" pihole)" == "healthy" ] ; then
        printf ' OK'
        echo -e "\nThe random password for your pihole is: $(docker logs pihole 2> /dev/null | grep 'Setting password:' | awk '{print $NF}')"
        exit 0
    else
        sleep 3
        printf '.'
    fi

    if [ $i -eq 20 ] ; then
        echo -e "\nTimed out waiting for Pi-hole start, consult check your container logs for more info (\`docker logs pihole\`)"
        exit 1
    fi
done;