#!/bin/bash -e
# Script for manually pushing the docker arm images for pi-hole org members only
# (no one else has docker repo permissions)
if [ ! -f ~/.docker/config.json ] ; then
    echo "Error: You should setup your docker push authorization first"
    exit 1
fi

parse_git_branch() {
    var="$(git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/')"
    # convert release/ to release-
    echo "${var/release\//release-}"
}

annotate() {
    local base=$1
    local image=$2
    local arch=${image##*_}
    local docker_arch=${arch_map[$arch]}

    if [ -z $docker_arch ]; then
        echo "Unknown arch in docker tag: ${arch}"
        exit 1
    else
        $dry docker manifest annotate ${base} ${image} --os linux --arch ${docker_arch}
    fi
}

namespace='pihole'
localimg='pihole'
remoteimg="$namespace/$localimg"
branch="$(parse_git_branch)"
local_version="$(cat VERSION)"
version="${version:-unset}"
dry="${dry}"
latest="${latest:-false}" # true as shell env var to deploy latest

# arch aliases
# ARMv6/armel doesn't have a FTL binary for v4.0 pi-hole
declare -A arch_map=( ["amd64"]="amd64" ["armhf"]="arm" ["aarch64"]="arm64")

# Set anything to dry prior to running this in order to print what would run instead of actually run it.
if [[ -n "$dry" ]]; then dry='echo '; fi

if [[ "$version" == 'unset' ]]; then
    if [[ "$branch" == "master" ]]; then
        echo "Version number var is unset and master branch needs a version...pass in \$version variable!"
        exit 1
    elif [[ "$branch" == "release-"* ]]; then
        version="$(echo $branch | grep -Po 'v[\d\w\.-]*')"
        echo "Version number is being taken from this release branch $version"
    else
        version="$branch"
        # Use a different image for segregating dev tags maybe?  Not right now, just a thought I had
        #remoteimg="${namespace}/${localimg}-dev"
        echo "Using the branch ($branch) for deployed image version since not passed in"
    fi
fi

echo "# DEPLOYING:"
echo "version: $version"
echo "branch: $branch"
[[ -n "$dry" ]] && echo "DRY RUN: $dry"
echo "Example tagging: docker tag ${localimg}:armhf ${remoteimg}:${version}_amd64"

if [[ -z "$dry" ]] ; then
    echo "Deleting all manifest data to work around cached old copies preventing updates"
    rm -rf ~/.docker/manifests/*
fi

$dry tox

images=()
for tag in ${!arch_map[@]}; do
    # Verison specific tags for ongoing history
    $dry docker tag $localimg:${local_version}_$tag $remoteimg:${version}_${tag}
    $dry docker push pihole/pihole:${version}_${tag}
    images+=(pihole/pihole:${version}_${tag})
done

$dry docker manifest create --amend pihole/pihole:${version} ${images[*]}

for image in "${images[@]}"; do
    annotate pihole/pihole:${version} ${image}
done

$dry docker manifest push pihole/pihole:${version}

# Floating latest tag alias
if [[ "$latest" == 'true' && "$branch" == "master" ]] ; then
    latestimg="$remoteimg:latest"
    $dry docker manifest create --amend "$latestimg" ${images[*]}
    for image in "${images[@]}"; do
        annotate "$latestimg" "${image}"
    done
    $dry docker manifest push "$latestimg"
fi
