FROM python:3.10-slim-bullseye

# Only works for docker CLIENT (bind mounted socket)
COPY --from=docker:20.10.17 /usr/local/bin/docker /usr/local/bin/

ARG packages
RUN apt-get update && \
    apt-get install -y python3-dev curl gcc make \
        libffi-dev libssl-dev ${packages} \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install --no-cache-dir -U pip pipenv

RUN curl -L https://github.com/docker/compose/releases/download/2.10.2/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose

COPY ./cmd.sh /usr/local/bin/
COPY Pipfile* /root/
WORKDIR /root

RUN pipenv install --system \
    && sed -i 's|/bin/sh|/bin/bash|g' /usr/local/lib/python3.10/site-packages/testinfra/backend/docker.py

RUN echo "set -ex && cmd.sh && \$@" > /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT entrypoint.sh
CMD cmd.sh
