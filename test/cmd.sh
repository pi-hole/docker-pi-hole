#!/usr/bin/env sh
set -eux

docker buildx build ./src --build-arg TARGETPLATFORM="${TARGETPLATFORM}" --tag pihole:${GIT_TAG} --no-cache
docker images pihole:${GIT_TAG}

# auto-format the pytest code
python3 -m black ./test/tests/

# TODO: Add junitxml output and have something consume it
COLUMNS=120 py.test -vv -n auto ./test/tests/
