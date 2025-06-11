FROM alpine:3.22 AS base-cli

RUN apk add --no-cache \
    ca-certificates \
    openssh-client \
    git \
    docker-cli \
    docker-cli-buildx \
    docker-cli-compose

FROM base-cli

COPY --chmod=0755 ./cmd.sh /usr/local/bin/cmd.sh
COPY requirements.txt /root/
WORKDIR /root

RUN apk add --no-cache \
    python3-dev \
    py3-pip \
    curl \
    && pip3 install --break-system-packages --no-cache-dir -U pip  \
    && pip3 install --break-system-packages --no-cache-dir -r requirements.txt \
    # Replace hardcoded /bin/sh with /bin/bash in testinfra docker backend
    # see https://github.com/pytest-dev/pytest-testinfra/issues/582 and similar issues
    && pythonversion=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))') \
    && sed -i 's|/bin/sh|/bin/bash|g' /usr/lib/python${pythonversion}/site-packages/testinfra/backend/docker.py

SHELL ["/bin/sh", "-c"]
CMD ["cmd.sh"]
