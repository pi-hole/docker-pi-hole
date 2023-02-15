# FROM ghcr.io/pi-hole/docker-pi-hole-base:bullseye-slim

FROM alpine:latest

# download a repo from github
RUN apk add --no-cache git libcap bash

# download a repo from github
RUN git clone --branch devel-v6 https://github.com/pi-hole/AdminLTE.git /var/www/html/admin
RUN git clone --branch development-v6 https://github.com/pi-hole/pi-hole.git /etc/.pihole

# Download the latest version of pihole-FTL for alpine:
# Probably need this to be built for different architectures
ADD https://ftl.pi-hole.net/new/http/pihole-FTL-musl-linux-x86_64 /usr/bin/pihole-FTL
ADD https://ftl.pi-hole.net/macvendor.db /macvendor.db

RUN cd /etc/.pihole && \
    install -Dm755 -d /opt/pihole && \
    install -Dm755 -t /opt/pihole gravity.sh && \
    install -Dm755 -t /opt/pihole ./advanced/Scripts/*.sh && \
    install -Dm755 -t /opt/pihole ./automated\ install/uninstall.sh && \
    install -Dm755 -t /opt/pihole ./advanced/Scripts/COL_TABLE && \
    install -Dm755 -t /usr/local/bin pihole && \
    install -Dm644 ./advanced/bash-completion/pihole /etc/bash_completion.d/pihole


ENV DNSMASQ_USER=pihole
ENV FTL_CMD=no-daemon
RUN addgroup -S pihole && adduser -S pihole -G pihole
# RUN groupadd pihole && useradd -r --no-user-group -g pihole -s /usr/sbin/nologin pihole

RUN apk add curl \
            bind-tools \
            nmap-ncat \
            psmisc \
            sudo \
            unzip \
            wget \
            libidn \
            nettle \
            libcap \
            openresolv \
            iproute2-ss \
            jq \
            coreutils \
            ncurses \
            dialog git newt procps dhcpcd openrc ncurses newt git

ADD bash_functions.sh /usr/bin/bash_functions.sh
ADD start.sh /usr/bin/start.sh

RUN chmod +x /usr/bin/start.sh
RUN chmod +x /usr/bin/pihole-FTL


HEALTHCHECK CMD dig +short +norecurse +retry=0 @127.0.0.1 pi.hole || exit 1

ENTRYPOINT [ "start.sh" ]



# RUN apt-get update \
#     && apt-get install --no-install-recommends -y \
#         # Packages Specific to Docker:
#         procps \
#         xz-utils \
#         curl \
#         ca-certificates \
#         git \
#         sudo \
#     && rm -rf /var/lib/apt/lists/*


# ARG PIHOLE_DOCKER_TAG
# RUN echo "${PIHOLE_DOCKER_TAG}" > /pihole.docker.tag

# ENTRYPOINT [ "/s6-init" ]

# COPY s6/debian-root /
# COPY s6/service /usr/local/bin/service

# RUN bash -ex install.sh 2>&1 && \
#     rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

# ARG PHP_ERROR_LOG
# ENV PHP_ERROR_LOG /var/log/lighttpd/error-pihole.log

# # Add PADD to the container, too.
# ADD https://raw.githubusercontent.com/pi-hole/PADD/PADD_FTLv6/padd.sh /usr/local/bin/padd
# RUN chmod +x /usr/local/bin/padd

# # IPv6 disable flag for networks/devices that do not support it
# ENV IPv6 True

# EXPOSE 53 53/udp
# EXPOSE 67/udp
# EXPOSE 80

# ENV S6_KEEP_ENV 1
# ENV S6_BEHAVIOUR_IF_STAGE2_FAILS 2
# ENV S6_CMD_WAIT_FOR_SERVICES_MAXTIME 0

# # ENV FTLCONF_LOCAL_IPV4 0.0.0.0
# ENV FTL_CMD no-daemon
# ENV DNSMASQ_USER pihole

# ENV PATH /opt/pihole:${PATH}

# HEALTHCHECK CMD dig +short +norecurse +retry=0 @127.0.0.1 pi.hole || exit 1

# SHELL ["/bin/bash", "-c"]