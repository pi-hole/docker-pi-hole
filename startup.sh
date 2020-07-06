#!/usr/bin/env zsh
[ -z ${Pihole_Version+x} ] && Pihole_Version='latest'
Pihole_Update_Profile_VERSION="v5.0"
SRC_Docker_image_base="pihole/pihole"
SRC_Docker_Image="${SRC_Docker_image_base}:${Pihole_Version}"
update_detected="no"
TZ="America/Chicago"

echo -e "Pihole-docker - Welcome to the startup/setup script."

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
    echo "Pihole-docker - Starting service\n"
    clear_service_container
    docker run \
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
        ${SRC_Docker_Image} &> /dev/null
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

if [[ -z "$(which docker)" ]] ;then
    echo "Pihole-docker - We can't seem to find docker on the system :\\"
    echo "Pihole-docker - Make it so the \"which\" command can find it and run gain."
    echo "Pihole-docker - Goodbye for now..."
    exit 42
fi

if [[ -z "$(docker ps -q -f name=pihole)" ]]; then
    Normal_docker_start
else
    echo -e "Pihole-docker - Service already running\n"
    update_container
    [[ "${update_detected}" == "yes" ]] && Normal_docker_start
fi
docker ps -f name=pihole ; exit_state "Finding the service profile in docker ps"
