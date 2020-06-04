#!/usr/bin/env bash
set -ex

# Script ran by Github actions for tests
#
# @environment ${ARCH}              The architecture to build. Example: amd64.
# @environment ${DEBIAN_VERSION}    Debian version to build. ('buster' or 'stretch').
# @environment ${ARCH_IMAGE}        What the Docker Hub Image should be tagged as. Example: pihole/pihole:master-amd64-stretch

# setup qemu/variables
docker run --rm --privileged multiarch/qemu-user-static:register --reset > /dev/null
. gh-actions-vars.sh

if [[ "$1" == "enter" ]]; then
    enter="-it --entrypoint=sh"
fi

# generate and build dockerfile
docker build --tag image_pipenv --file Dockerfile_build .
docker run --rm \
    --volume /var/run/docker.sock:/var/run/docker.sock \
    --volume "$(pwd):/$(pwd)" \
    --workdir "$(pwd)" \
    --env PIPENV_CACHE_DIR="$(pwd)/.pipenv" \
    --env ARCH="${ARCH}" \
    --env ARCH_IMAGE="${ARCH_IMAGE}" \
    --env DEBIAN_VERSION="${DEBIAN_VERSION}" \
    ${enter} image_pipenv

mkdir -p ".gh-workspace/${DEBIAN_VERSION}/"
echo "${ARCH_IMAGE}" | tee "./.gh-workspace/${DEBIAN_VERSION}/${ARCH}"
