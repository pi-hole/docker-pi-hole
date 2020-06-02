ARG PIHOLE_BASE
FROM $PIHOLE_BASE

ARG PIHOLE_ARCH
ENV PIHOLE_ARCH "${PIHOLE_ARCH}"
ARG S6_ARCH
ARG S6_VERSION
ENV S6OVERLAY_RELEASE "https://github.com/just-containers/s6-overlay/releases/download/${S6_VERSION}/s6-overlay-${S6_ARCH}.tar.gz"

COPY install.sh /usr/local/bin/install.sh
COPY VERSION /etc/docker-pi-hole-version
ENV PIHOLE_INSTALL /root/ph_install.sh

RUN bash -ex install.sh 2>&1 && \
    rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

ENTRYPOINT [ "/s6-init" ]

ADD s6/debian-root /
COPY s6/service /usr/local/bin/service

# php config start passes special ENVs into
ARG PHP_ENV_CONFIG
ENV PHP_ENV_CONFIG "${PHP_ENV_CONFIG}"
ARG PHP_ERROR_LOG
ENV PHP_ERROR_LOG "${PHP_ERROR_LOG}"
COPY ./start.sh /
COPY ./bash_functions.sh /

# IPv6 disable flag for networks/devices that do not support it
ENV IPv6 True

EXPOSE 53 53/udp
EXPOSE 67/udp
EXPOSE 80
EXPOSE 443

ENV S6_LOGGING 0
ENV S6_KEEP_ENV 1
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS 2

ENV ServerIP 0.0.0.0
ENV FTL_CMD no-daemon
ENV DNSMASQ_USER root

ARG PIHOLE_VERSION
ENV VERSION "${PIHOLE_VERSION}"
ENV PATH /opt/pihole:${PATH}

ARG NAME
LABEL image="${NAME}:${PIHOLE_VERSION}_${PIHOLE_ARCH}"
ARG MAINTAINER
LABEL maintainer="${MAINTAINER}"
LABEL url="https://www.github.com/pi-hole/docker-pi-hole"

HEALTHCHECK CMD dig +norecurse +retry=0 @127.0.0.1 pi.hole || exit 1

SHELL ["/bin/bash", "-c"]
