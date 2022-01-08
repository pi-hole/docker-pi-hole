ARG PIHOLE_BASE
FROM "${PIHOLE_BASE:-ghcr.io/pi-hole/docker-pi-hole-base:bullseye-slim}"

ARG PIHOLE_DOCKER_TAG
ENV PIHOLE_DOCKER_TAG "${PIHOLE_DOCKER_TAG}"

ENV S6_OVERLAY_VERSION v2.2.0.3

COPY install.sh /usr/local/bin/install.sh
ENV PIHOLE_INSTALL /etc/.pihole/automated\ install/basic-install.sh

ENTRYPOINT [ "/s6-init" ]

COPY s6/debian-root /
COPY s6/service /usr/local/bin/service

RUN bash -ex install.sh 2>&1 && \
    rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

# php config start passes special ENVs into
ARG PHP_ENV_CONFIG
ENV PHP_ENV_CONFIG /etc/lighttpd/conf-enabled/15-fastcgi-php.conf
ARG PHP_ERROR_LOG
ENV PHP_ERROR_LOG /var/log/lighttpd/error.log
COPY ./start.sh /
COPY ./bash_functions.sh /

# IPv6 disable flag for networks/devices that do not support it
ENV IPv6 True

EXPOSE 53 53/udp
EXPOSE 67/udp
EXPOSE 80

ENV S6_LOGGING 0
ENV S6_KEEP_ENV 1
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS 2

ENV ServerIP 0.0.0.0
ENV FTL_CMD no-daemon
ENV DNSMASQ_USER pihole

ENV PATH /opt/pihole:${PATH}

HEALTHCHECK CMD dig +short +norecurse +retry=0 @127.0.0.1 pi.hole || exit 1

SHELL ["/bin/bash", "-c"]