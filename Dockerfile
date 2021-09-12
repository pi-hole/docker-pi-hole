ARG PIHOLE_BASE
FROM "${PIHOLE_BASE:-debian:buster-slim}"

ARG CORE_VERSION
ENV CORE_VERSION "${CORE_VERSION}"
ARG WEB_VERSION
ENV WEB_VERSION "${WEB_VERSION}"
ARG FTL_VERSION
ENV FTL_VERSION "${FTL_VERSION}"
ARG PIHOLE_VERSION
ENV PIHOLE_VERSION "${PIHOLE_VERSION}"

ENV S6_OVERLAY_VERSION v2.1.0.2

COPY install.sh /usr/local/bin/install.sh
ENV PIHOLE_INSTALL /etc/.pihole/automated\ install/basic-install.sh

RUN bash -ex install.sh 2>&1 && \
    rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

ENTRYPOINT [ "/s6-init" ]

ADD s6/debian-root /
COPY s6/service /usr/local/bin/service

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
ENV DNSMASQ_USER root

ENV PATH /opt/pihole:${PATH}

HEALTHCHECK CMD dig +short +norecurse +retry=0 @127.0.0.1 pi.hole || exit 1

SHELL ["/bin/bash", "-c"]