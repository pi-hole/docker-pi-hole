ARG alpine_version="3.18"
ARG docker_version="24.0.7"

FROM docker:${docker_version}-cli-alpine${alpine_version}

COPY --chmod=0755 ./cmd.sh /usr/local/bin/cmd.sh
COPY --chmod=0755 ./entrypoint.sh /usr/local/bin/entrypoint.sh
COPY Pipfile* /root/
WORKDIR /root

RUN apk add --no-cache \
    python3-dev \
    py3-pip \
    curl \
    && pip3 install --no-cache-dir -U pip pipenv \
    && pipenv install --system \
    # Not 100% sure what this line does, but it's always been in the Dockerfile (aside from pointing at a different file)
    # Tests fall over without it. Investigate later.
    && sed -i 's|/bin/sh|/bin/bash|g' /usr/lib/python3.11/site-packages/testinfra/backend/docker.py

ENTRYPOINT entrypoint.sh
CMD cmd.sh
