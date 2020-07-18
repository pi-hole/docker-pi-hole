#!/usr/bin/env bash
set -ex
# Github Actions Job for merging/deploying all architectures (post-test passing)
. gh-actions-vars.sh

function annotate() {
    local base=$1
    local image=$2
    local arch=$3
    local annotate_flags="${annotate_map[$arch]}"

    $dry docker manifest annotate ${base} ${image} --os linux ${annotate_flags}
}

function create_manifest() {
    local debian_version=$1
    local images=()
    cd "${debian_version}"

    for arch in *; do
        arch_image=$(cat "${arch}")
        docker pull "${arch_image}"
        images+=("${arch_image}")
    done

    multiarch_images=$(get_multiarch_images)
    for docker_tag in ${multiarch_images}; do
        docker manifest create ${docker_tag} ${images[*]}
        for arch in *; do
            arch_image=$(cat "${arch}")
            annotate "${docker_tag}" "${arch_image}" "${arch}"
        done

        docker manifest inspect "${docker_tag}"
        docker manifest push --purge "${docker_tag}"
    done
    cd ../
}

function get_multiarch_images() {
    multiarch_images="${MULTIARCH_IMAGE}-${debian_version}"
    if [[ "${debian_version}" == "${DEFAULT_DEBIAN_VERSION}" ]] ; then
        # default debian version gets a non-debian tag as well as latest tag
        multiarch_images="${multiarch_images} ${MULTIARCH_IMAGE} ${LATEST_IMAGE}"
    fi
    echo "${multiarch_images}"
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
# I tried to keep this login command outside of this script
# but for some reason auth would always fail in Github Actions.
# I think setting up a cred store would fix it
# https://docs.docker.com/engine/reference/commandline/login/#credentials-store
echo "${DOCKERHUB_PASS}" | docker login --username="${DOCKERHUB_USER}" --password-stdin
docker info

ls -lat ./.gh-workspace/
cd .gh-workspace

for debian_version in *; do
    create_manifest "${debian_version}"
done
