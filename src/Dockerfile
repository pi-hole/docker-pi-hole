ARG CONTAINER="3.18"
FROM alpine:${CONTAINER}
# https://docs.docker.com/engine/reference/builder/#automatic-platform-args-in-the-global-scope

ARG TARGETPLATFORM
ARG WEB_BRANCH="development-v6"
ARG CORE_BRANCH="development-v6"
ARG FTL_BRANCH="development-v6"
ARG PIHOLE_DOCKER_TAG="unknown"

ENV DNSMASQ_USER=pihole
ENV FTL_CMD=no-daemon

RUN apk add --no-cache \
    bash \
    bind-tools \
    binutils \
    coreutils \
    curl \
    git \ 
    iproute2-ss \
    jq \
    libcap \
    ncurses \
    nmap-ncat \
    procps-ng \
    psmisc \
    shadow \
    sudo \
    tzdata \
    unzip \
    wget

ADD https://ftl.pi-hole.net/macvendor.db /macvendor.db
COPY crontab.txt /crontab.txt

# download a the main repos from github
RUN git clone --depth 1 --single-branch --branch ${WEB_BRANCH} https://github.com/pi-hole/AdminLTE.git /var/www/html/admin && \
    git clone --depth 1 --single-branch --branch ${CORE_BRANCH} https://github.com/pi-hole/pi-hole.git /etc/.pihole ;\
    # Download the latest version of pihole-FTL for alpine:
    if   [ "$TARGETPLATFORM" = "linux/amd64" ];    then FTLARCH=amd64; \
    elif [ "$TARGETPLATFORM" = "linux/386" ];      then FTLARCH=386; \
    elif [ "$TARGETPLATFORM" = "linux/arm/v6" ];   then FTLARCH=armv6; \
    elif [ "$TARGETPLATFORM" = "linux/arm/v7" ];   then FTLARCH=armv7; \
    elif [ "$TARGETPLATFORM" = "linux/arm64" ];    then FTLARCH=arm64; \
    elif [ "$TARGETPLATFORM" = "linux/riscv64" ];  then FTLARCH=riscv64; \
    else FTLARCH=amd64; fi \
    && echo "Arch: ${TARGETPLATFORM}, FTLARCH: ${FTLARCH}" \
    && curl -sSL "https://ftl.pi-hole.net/${FTL_BRANCH}/pihole-FTL-${FTLARCH}" -o /usr/bin/pihole-FTL \
    && chmod +x /usr/bin/pihole-FTL \
    && readelf -h /usr/bin/pihole-FTL || cat /usr/bin/pihole-FTL

RUN cd /etc/.pihole && \
    install -Dm755 -d /opt/pihole && \
    install -Dm755 -t /opt/pihole gravity.sh && \
    install -Dm755 -t /opt/pihole ./advanced/Scripts/*.sh && \
    install -Dm755 -t /opt/pihole ./automated\ install/uninstall.sh && \
    install -Dm755 -t /opt/pihole ./advanced/Scripts/COL_TABLE && \
    install -Dm755 -t /usr/local/bin pihole && \
    install -Dm644 ./advanced/bash-completion/pihole /etc/bash_completion.d/pihole && \
    install -T -m 0755 ./advanced/Templates/pihole-FTL-prestart.sh /opt/pihole/pihole-FTL-prestart.sh && \
    install -T -m 0755 ./advanced/Templates/pihole-FTL-poststop.sh /opt/pihole/pihole-FTL-poststop.sh && \
    addgroup -S pihole && adduser -S pihole -G pihole && \
    echo "${PIHOLE_DOCKER_TAG}" > /pihole.docker.tag

COPY --chmod=0755 bash_functions.sh /usr/bin/bash_functions.sh
COPY --chmod=0755 start.sh /usr/bin/start.sh

HEALTHCHECK CMD dig +short +norecurse +retry=0 @127.0.0.1 pi.hole || exit 1

ENTRYPOINT [ "start.sh" ]
