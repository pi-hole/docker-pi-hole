# syntax=docker/dockerfile:1
ARG FTL_SOURCE=remote
# Pull Stable images
FROM alpine:3.22 AS base

ARG TARGETPLATFORM
ARG WEB_BRANCH="development"
ARG CORE_BRANCH="development"
ARG FTL_BRANCH="development"
ARG PIHOLE_DOCKER_TAG="dev-localbuild"
ARG PADD_BRANCH="development"

ARG CORE_FORK="pi-hole"
ARG WEB_FORK="pi-hole"
ARG PADD_FORK="pi-hole"

ARG PIHOLE_UID=1000
ARG PIHOLE_GID=1000

ENV DNSMASQ_USER=pihole
ENV FTL_CMD=no-daemon

RUN apk add --no-cache \
    bash \
    bash-completion \
    bind-tools \
    binutils \
    coreutils \
    curl \
    git \
    # Install grep to avoid issues in pihole -w/b with the default busybox grep
    grep \
    iproute2 \
    jq \
    libcap \
    logrotate \
    ncurses \
    procps-ng \
    psmisc \
    shadow \
    sudo \
    tzdata \
    unzip \
    wget

# For nightly images, we install gdb and screen for ease of debugging (this is
# not included in the default image to keep it small), and also prepare the
# system for a core dump. Furthermore, we already add the required signal
# instructions to the gdb config file
RUN if [ "${PIHOLE_DOCKER_TAG}" = "nightly" ]; then \
    apk add --no-cache gdb screen && \
    echo "ulimit -c unlimited" >> /etc/profile && \
    echo "handle SIGHUP nostop SIGPIPE nostop SIGTERM nostop SIG32 nostop SIG33 nostop SIG34 nostop SIG35 nostop SIG36 nostop SIG37 nostop SIG38 nostop SIG39 nostop SIG40 nostop SIG41 nostop" > /root/.gdbinit; \
    fi

ADD https://ftl.pi-hole.net/macvendor.db /macvendor.db
COPY crontab.txt /crontab.txt

# Add PADD to the container, too.
ADD --chmod=0755 https://raw.githubusercontent.com/${PADD_FORK}/PADD/${PADD_BRANCH}/padd.sh /usr/local/bin/padd

# download a the main repos from github 
# if the branch is master we clone the latest tag as sometimes the master branch contains meta changes that have not been tagged
# (we need to create a new "master" branch to avoid the "detached HEAD" state for the version check to work correctly)                                      

RUN clone_repo() { \
        FORK="$1"; \
        REPO="$2"; \
        BRANCH="$3"; \
        DEST="$4"; \
        CLONE_BRANCH="$BRANCH"; \
        if [ "$BRANCH" = "master" ]; then \
            CLONE_BRANCH=$(curl -s https://api.github.com/repos/${FORK}/${REPO}/releases/latest | jq -r .tag_name); \
        fi; \
        git clone --branch "$CLONE_BRANCH" --single-branch --depth 1 "https://github.com/${FORK}/${REPO}.git" "$DEST"; \
        cd "$DEST"; \
        if [ "$BRANCH" = "master" ]; then git checkout -b master; fi; \
    }; \
    clone_repo "${WEB_FORK}" "web" "${WEB_BRANCH}" "/var/www/html/admin"; \
    clone_repo "${CORE_FORK}" "pi-hole" "${CORE_BRANCH}" "/etc/.pihole"


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
    addgroup -S pihole -g ${PIHOLE_GID} && adduser -S pihole -G pihole -u ${PIHOLE_UID} && \
    echo "${PIHOLE_DOCKER_TAG}" > /pihole.docker.tag

COPY --chmod=0755 bash_functions.sh /usr/bin/bash_functions.sh
COPY --chmod=0755 start.sh /usr/bin/start.sh

EXPOSE 53 53/udp
EXPOSE 67/udp
EXPOSE 80
EXPOSE 123/udp
EXPOSE 443

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
    && if [ "${FTL_BRANCH}" = "master" ]; then URL="https://github.com/pi-hole/ftl/releases/latest/download"; else URL="https://ftl.pi-hole.net/${FTL_BRANCH}"; fi \
    && curl -sSL "${URL}/pihole-FTL-${FTLARCH}" -o /usr/bin/pihole-FTL \
    && chmod +x /usr/bin/pihole-FTL \
    && readelf -h /usr/bin/pihole-FTL || (echo "Error with downloaded FTL binary" && exit 1) \
    && /usr/bin/pihole-FTL  -vv

FROM base AS local-ftl-install
# pihole-FTL must be built from source and copied to the src directory first!
COPY --chmod=0755 pihole-FTL /usr/bin/pihole-FTL
RUN  readelf -h /usr/bin/pihole-FTL || (echo "Error with local FTL binary" && exit 1)

# Use the appropriate FTL Install stage based on the FTL_SOURCE build-arg
FROM ${FTL_SOURCE}-ftl-install AS final

HEALTHCHECK CMD dig -p $(pihole-FTL --config dns.port) +short +norecurse +retry=0 @127.0.0.1 pi.hole || exit 1

ENTRYPOINT ["start.sh"]
