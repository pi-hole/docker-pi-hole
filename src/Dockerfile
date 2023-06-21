ARG CONTAINER="alpine:edge"
FROM ${CONTAINER}
# https://docs.docker.com/engine/reference/builder/#automatic-platform-args-in-the-global-scope
ARG TARGETPLATFORM

# download a repo from github
# TODO - probably remove a lot of these
RUN apk add --no-cache git \
                       libcap \
                       bash \
                       curl \
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
                       dialog \
                       newt \
                       procps \
                       dhcpcd \
                       openrc \
                       ncurses \
                       newt

# download a the main repos from github
RUN git clone --branch development-v6 https://github.com/pi-hole/AdminLTE.git /var/www/html/admin
RUN git clone --branch development-v6 https://github.com/pi-hole/pi-hole.git /etc/.pihole

# Download the latest version of pihole-FTL for alpine:
# Probably need this to be built for different FTLARCHs
RUN if [ "$TARGETPLATFORM" = "linux/amd64" ]; then FTLARCH=amd64; \
    elif [ "$TARGETPLATFORM" = "linux/386" ]; then FTLARCH=386; \
    elif [ "$TARGETPLATFORM" = "linux/arm/v6" ]; then FTLARCH=armv6; \
    elif [ "$TARGETPLATFORM" = "linux/arm/v7" ]; then FTLARCH=armv7; \
    elif [ "$TARGETPLATFORM" = "linux/arm64/v8" ]; then FTLARCH=armv64; \
    elif [ "$TARGETPLATFORM" = "linux/riscv64" ]; then FTLARCH=riscv64; \
    else FTLARCH=amd64; fi \
    && curl -sSL "https://ftl.pi-hole.net/development-v6/pihole-FTL-${FTLARCH}" -o /usr/bin/pihole-FTL && \
    chmod +x /usr/bin/pihole-FTL


ADD https://ftl.pi-hole.net/macvendor.db /macvendor.db

RUN cd /etc/.pihole && \
    install -Dm755 -d /opt/pihole && \
    install -Dm755 -t /opt/pihole gravity.sh && \
    install -Dm755 -t /opt/pihole ./advanced/Scripts/*.sh && \
    install -Dm755 -t /opt/pihole ./automated\ install/uninstall.sh && \
    install -Dm755 -t /opt/pihole ./advanced/Scripts/COL_TABLE && \
    install -Dm755 -t /usr/local/bin pihole && \
    install -Dm644 ./advanced/bash-completion/pihole /etc/bash_completion.d/pihole && \
    install -Dm644 ./advanced/Templates/pihole.cron /var/spool/cron/crontabs/pihole && \
    # Randomize gravity update time
    sed -i "s/59 1 /$((1 + RANDOM % 58)) $((3 + RANDOM % 2))/" /var/spool/cron/crontabs/pihole && \
    # Randomize update checker time
    sed -i "s/59 17/$((1 + RANDOM % 58)) $((12 + RANDOM % 8))/" /var/spool/cron/crontabs/pihole && \
    # Grab some useful bits from FTL's service scripts
    install -T -m 0755 ./advanced/Templates/pihole-FTL-prestart.sh /opt/pihole/pihole-FTL-prestart.sh && \
    install -T -m 0755 ./advanced/Templates/pihole-FTL-poststop.sh /opt/pihole/pihole-FTL-poststop.sh



ENV DNSMASQ_USER=pihole
ENV FTL_CMD=no-daemon
RUN addgroup -S pihole && adduser -S pihole -G pihole
# RUN groupadd pihole && useradd -r --no-user-group -g pihole -s /usr/sbin/nologin pihole

ADD bash_functions.sh /usr/bin/bash_functions.sh
ADD start.sh /usr/bin/start.sh

RUN chmod +x /usr/bin/start.sh



HEALTHCHECK CMD dig +short +norecurse +retry=0 @127.0.0.1 pi.hole || exit 1

ENTRYPOINT [ "start.sh" ]
