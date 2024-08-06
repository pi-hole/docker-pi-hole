ARG alpine_version="3.20"
ARG docker_version="27.1.1"

FROM docker:${docker_version}-cli-alpine${alpine_version}

COPY --chmod=0755 ./cmd.sh /usr/local/bin/cmd.sh
COPY requirements.txt /root/
WORKDIR /root

RUN apk add --no-cache \
    python3-dev \
    py3-pip \
    curl \
    && pip3 install --break-system-packages --no-cache-dir -U pip  \
    && pip3 install --break-system-packages --no-cache-dir -r requirements.txt \
    # Not 100% sure what this line does, but it's always been in the Dockerfile (aside from pointing at a different file)
    # Tests fall over without it. Investigate later.
    && sed -i 's|/bin/sh|/bin/bash|g' /usr/lib/python3.11/site-packages/testinfra/backend/docker.py

SHELL ["/bin/sh", "-c"]
CMD ["cmd.sh"]
