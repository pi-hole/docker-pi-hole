#!/usr/bin/env bash
set -ex

# Circle CI Job for single architecture

# setup qemu/variables
docker run --rm --privileged multiarch/qemu-user-static:register --reset > /dev/null
. circle-vars.sh

if [[ "$1" == "enter" ]]; then
    enter="-it --entrypoint=sh"
fi

# generate and build dockerfile
docker build -t image_pipenv -f Dockerfile_build .
env > /tmp/env
docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$(pwd):/$(pwd)" \
    -w "$(pwd)" \
    -e PIPENV_CACHE_DIR="$(pwd)/.pipenv" \
    --env-file /tmp/env \
    $enter image_pipenv

docker images

test -z "${CIRCLE_PROJECT_REPONAME}" && exit 0
# The rest is circle-ci only
echo $DOCKERHUB_PASS | docker login --username=$DOCKERHUB_USER --password-stdin
docker push $ARCH_IMAGE
mkdir -p ci-workspace
echo "$ARCH_IMAGE" | tee ./ci-workspace/$ARCH
