FROM python:3.10-alpine3.18

# Only works for docker CLIENT (bind mounted socket)
COPY --from=docker:24-cli /usr/local/bin/docker /usr/local/bin/

RUN apk add --no-cache \
    curl \
    && pip3 install --no-cache-dir -U pip pipenv

COPY ./cmd.sh /usr/local/bin/
COPY Pipfile* /root/
WORKDIR /root

RUN pipenv install --system \
    && sed -i 's|/bin/sh|/bin/bash|g' /usr/local/lib/python3.10/site-packages/testinfra/backend/docker.py

RUN echo "set -ex && cmd.sh && \$@" > /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT entrypoint.sh
CMD cmd.sh
