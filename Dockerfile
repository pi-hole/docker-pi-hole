# syntax=docker/dockerfile:1.3
ARG PIHOLE_BASE
# =ghcr.io/pi-hole/docker-pi-hole-base:bullseye-slim
FROM ${PIHOLE_BASE}

ARG PIHOLE_DOCKER_TAG
ENV PIHOLE_DOCKER_TAG "${PIHOLE_DOCKER_TAG}"
ARG TARGETPLATFORM
ARG BUILDPLATFORM

ARG aptCacher
ARG S6_OVERLAY_VERSION

ENV PIHOLE_INSTALL /etc/.pihole/automated\ install/basic-install.sh
ENV S6_GLOBAL_PATH=/command:/usr/bin:/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/sbin:/bin:/opt/pihole;

#add apt-cacher setting if present:
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
#hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt if [[ -n ${aptCacher} ]]; then printf "Acquire::http::Proxy \"http://%s:3142\";" "${aptCacher}">/etc/apt/apt.conf.d/01proxy \
    && printf "Acquire::https::Proxy \"http://%s:3142\";" "${aptCacher}">>/etc/apt/apt.conf.d/01proxy ; fi \
    && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates tar \
    curl procps xz-utils dnsutils vim cron curl iputils-ping psmisc sudo unzip idn2 sqlite3 libcap2-bin dns-root-data \
    libcap2 netcat lighttpd php-common php-cgi php-sqlite3 php-xml php-intl php-json whiptail
COPY install.sh /usr/local/bin/install.sh
RUN echo "Buidling pihole version ${PIHOLE_DOCKER_TAG} with s6 ${S6_OVERLAY_VERSION} for ${TARGETPLATFORM}" && bash -x install.sh 2>&1 \
    # S6_GLOBAL_PATH ha nos effect
    && mkdir -p /etc/s6-overlay/config/ && echo "${S6_GLOBAL_PATH}" > /etc/s6-overlay/config/global_path
# php config start passes special ENVs into
ARG PHP_ENV_CONFIG
ENV PHP_ENV_CONFIG /etc/lighttpd/conf-enabled/15-fastcgi-php.conf
ARG PHP_ERROR_LOG
ENV PHP_ERROR_LOG /var/log/lighttpd/error.log
COPY s6/debian-root /
COPY s6/service /usr/local/bin/service
COPY ./start.sh /
COPY ./bash_functions.sh /
RUN find /etc/s6-overlay -type f -exec chmod +x {} \;
#S6 customisations
ENV S6_LOGGING 0
ENV S6_KEEP_ENV 1
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS 1

# IPv6 disable flag for networks/devices that do not support it
ENV IPv6 True
ENV ServerIP 0.0.0.0
ENV FTL_CMD no-daemon
ENV DNSMASQ_USER pihole

EXPOSE 53 53/udp
EXPOSE 67/udp
EXPOSE 80

HEALTHCHECK CMD dig +short +norecurse +retry=0 @127.0.0.1 pi.hole || exit 1

SHELL ["/bin/bash", "-c"]
ENTRYPOINT [ "/s6-init" ]
