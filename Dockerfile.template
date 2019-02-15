FROM {{ pihole.base }}

ENV S6OVERLAY_RELEASE https://github.com/just-containers/s6-overlay/releases/download/{{ pihole.s6_version }}/s6-overlay-{{ pihole.s6arch }}.tar.gz
COPY install.sh /usr/local/bin/install.sh
COPY VERSION /etc/docker-pi-hole-version
ENV PIHOLE_INSTALL /root/ph_install.sh

RUN bash -ex install.sh 2>&1 && \
    rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

ENTRYPOINT [ "/s6-init" ]

ADD s6/debian-root /
COPY s6/service /usr/local/bin/service

# php config start passes special ENVs into
ENV PHP_ENV_CONFIG '{{ pihole.php_env_config }}'
ENV PHP_ERROR_LOG '{{ pihole.php_error_log }}'
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

ENV VERSION {{ pihole.version }}
ENV ARCH {{ pihole.arch }}
ENV PATH /opt/pihole:${PATH}

LABEL image="{{ pihole.name }}:{{ pihole.version }}_{{ pihole.arch }}"
LABEL maintainer="{{ pihole.maintainer }}"
LABEL url="https://www.github.com/pi-hole/docker-pi-hole"

HEALTHCHECK CMD dig @127.0.0.1 pi.hole || exit 1

SHELL ["/bin/bash", "-c"]
