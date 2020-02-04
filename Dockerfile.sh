#!/usr/bin/env sh
# alpine sh only

set -eux
./Dockerfile.py -v --arch="${ARCH}" --hub_tag="${ARCH_IMAGE}"
# TODO: Add junitxml output and have circleci consume it
# 2 parallel max b/c race condition with docker fixture (I think?)
py.test -vv -n 2 -k "${ARCH}" ./test/
