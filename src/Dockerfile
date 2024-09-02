# syntax=docker/dockerfile:1
ARG FTL_SOURCE=remote
ARG alpine_version="3.20" 
FROM alpine:${alpine_version} AS base
# https://docs.docker.com/engine/reference/builder/#automatic-platform-args-in-the-global-scope

ARG TARGETPLATFORM
ARG WEB_BRANCH="development"
ARG CORE_BRANCH="development"
ARG FTL_BRANCH="development"
ARG PIHOLE_DOCKER_TAG="dev-localbuild"
ARG PADD_BRANCH="development"

ENV DNSMASQ_USER=pihole
ENV FTL_CMD=no-daemon

RUN apk add --no-cache \
    bash \
    bind-tools \
    binutils \
    coreutils \
    curl \
    git \
    # Install grep to avoid issues in pihole -w/b with the default busybox grep
    grep \
    iproute2-ss \
    jq \
    libcap \
    logrotate \
    ncurses \
    nmap-ncat \
    procps-ng \
    psmisc \
    shadow \
    sudo \
    tini \
    tzdata \
    unzip \
    wget 

ADD https://ftl.pi-hole.net/macvendor.db /macvendor.db
COPY crontab.txt /crontab.txt

# Add PADD to the container, too.
ADD --chmod=0755 https://raw.githubusercontent.com/pi-hole/PADD/${PADD_BRANCH}/padd.sh /usr/local/bin/padd

# download a the main repos from github
RUN git clone --depth 1 --single-branch --branch ${WEB_BRANCH} https://github.com/pi-hole/web.git /var/www/html/admin && \
    git clone --depth 1 --single-branch --branch ${CORE_BRANCH} https://github.com/pi-hole/pi-hole.git /etc/.pihole

RUN cd /etc/.pihole && \
    install -Dm755 -d /opt/pihole && \
    install -Dm755 -t /opt/pihole gravity.sh && \
    install -Dm755 -t /opt/pihole ./advanced/Scripts/*.sh && \
    install -Dm755 -t /opt/pihole ./advanced/Scripts/COL_TABLE && \
    install -Dm755 -d /etc/pihole && \
    install -Dm644 -t /etc/pihole ./advanced/Templates/logrotate && \
    install -Dm755 -d /var/log/pihole && \
    install -Dm755 -d /var/lib/logrotate && \
    install -Dm755 -t /usr/local/bin pihole && \
    install -Dm644 ./advanced/bash-completion/pihole /etc/bash_completion.d/pihole && \
    install -T -m 0755 ./advanced/Templates/pihole-FTL-prestart.sh /opt/pihole/pihole-FTL-prestart.sh && \
    install -T -m 0755 ./advanced/Templates/pihole-FTL-poststop.sh /opt/pihole/pihole-FTL-poststop.sh && \
    addgroup -S pihole && adduser -S pihole -G pihole && \
    echo "${PIHOLE_DOCKER_TAG}" > /pihole.docker.tag

COPY --chmod=0755 bash_functions.sh /usr/bin/bash_functions.sh
COPY --chmod=0755 start.sh /usr/bin/start.sh

## Buildkit can do some fancy stuff and we can use it to either download FTL from ftl.pi-hole.net or use a local copy

FROM base AS remote-ftl-install
# Default stage if FTL_SOURCE is not explicitly set to "local"
# Download the latest version of pihole-FTL for the correct architecture
RUN if   [ "$TARGETPLATFORM" = "linux/amd64" ];    then FTLARCH=amd64; \
    elif [ "$TARGETPLATFORM" = "linux/386" ];      then FTLARCH=386; \
    elif [ "$TARGETPLATFORM" = "linux/arm/v6" ];   then FTLARCH=armv6; \
    elif [ "$TARGETPLATFORM" = "linux/arm/v7" ];   then FTLARCH=armv7; \
    # Note for the future, "linux/arm6/v8" is not a valid value for TARGETPLATFORM, despite the CI platform name being that.
    elif [ "$TARGETPLATFORM" = "linux/arm64" ];    then FTLARCH=arm64; \
    elif [ "$TARGETPLATFORM" = "linux/riscv64" ];  then FTLARCH=riscv64; \
    else FTLARCH=amd64; fi \
    && echo "Arch: ${TARGETPLATFORM}, FTLARCH: ${FTLARCH}" \
    && curl -sSL "https://ftl.pi-hole.net/${FTL_BRANCH}/pihole-FTL-${FTLARCH}" -o /usr/bin/pihole-FTL \
    && chmod +x /usr/bin/pihole-FTL \
    && readelf -h /usr/bin/pihole-FTL || cat /usr/bin/pihole-FTL

FROM base AS local-ftl-install
# pihole-FTL must be built from source and copied to the src directory first!
COPY --chmod=0755 pihole-FTL /usr/bin/pihole-FTL

# Use the appropriate FTL Install stage based on the FTL_SOURCE build-arg
FROM ${FTL_SOURCE}-ftl-install AS final

HEALTHCHECK CMD dig +short +norecurse +retry=0 @127.0.0.1 pi.hole || exit 1

ENTRYPOINT ["/sbin/tini", "--", "start.sh"]
