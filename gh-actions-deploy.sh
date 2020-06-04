#!/usr/bin/env bash
set -ex
# Github Actions Job for merging/deploying all architectures (post-test passing)
. gh-actions-vars.sh

annotate() {
    local base=$1
    local image=$2
    local arch=$3
    local annotate_flags="${annotate_map[$arch]}"

    # TODO what is $dry and where does it come from?
    $dry docker manifest annotate ${base} ${image} --os linux ${annotate_flags}
}

# Keep in sync with build.yml names
declare -A annotate_map=( 
    ["amd64"]="--arch amd64" 
    ["armel"]="--arch arm --variant v6" 
    ["armhf"]="--arch arm --variant v7" 
    ["arm64"]="--arch arm64 --variant v8"
)

mkdir -p ~/.docker
export DOCKER_CLI_EXPERIMENTAL='enabled'
echo "{}" | jq '.experimental="enabled"' | tee ~/.docker/config.json
docker info

images=()
ls -lat ./.gh-workspace/
cd .gh-workspace

for debian_arch in *; do
    arch_image=$(cat "${debian_arch}")
    docker pull "${arch_image}"
    images+=("${arch_image}")
done

for docker_tag in ${MULTIARCH_IMAGE} ${MULTIARCH_IMAGE_DEBIAN} ${LATEST_IMAGE}; do
    docker manifest create ${docker_tag} ${images[*]}
    for debian_arch in *; do
        arch_image=$(cat "${debian_arch}")
        arch=${debian_arch%-*} # amd64-buster => amd64
        annotate "${docker_tag}" "${arch_image}" "${arch}"
    done

    docker manifest inspect "${docker_tag}"
    docker manifest push --purge "$docker_tag"
done;
