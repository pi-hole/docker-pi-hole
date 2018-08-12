#!/bin/bash -ex
# Script for manually pushing the docker arm images for diginc only 
# (no one else has docker repo permissions)
if [ ! -f ~/.docker/config.json ] ; then
    echo "Error: You should setup your docker push authorization first"
    exit 1
fi

parse_git_branch() {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'
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
version="${version:-unset}"
dry="${dry}"
latest="${latest:-false}" # true as shell env var to deploy latest

# arch aliases
declare -A arch_map=( ["amd64"]="amd64" ["armhf"]="arm" ["aarch64"]="arm64")

if [[ -n "$dry" ]]; then dry='echo '; fi

if [[ "$version" == 'unset' ]]; then
    if [[ "$branch" == "master" ]]; then
        echo "Version number var is unset and master branch needs a version...pass in \$version variable!"
        exit 1
    elif [[ "$branch" = "release/"* ]]; then
        version="$(echo $branch | grep -Po 'v[\d\.-]*')"
        echo "Version number is being taken from this release branch $version"
    else
        version="$branch"
        remoteimg="${namespace}/${localimg}-dev"
        echo "Using the branch ($branch) for deployed image version since not passed in"
    fi
fi

echo "# DEPLOYING:"
echo "version: $version"
echo "branch: $branch"
[[ -n "$dry" ]] && echo "DRY RUN: $dry"
echo "Example tagging: docker tag $localimg:$tag $remoteimg:${version}_amd64"

$dry ./Dockerfile.py --arch=amd64 --arch=armhf --arch=aarch64

images=()
# ARMv6/armel doesn't have a FTL binary for v4.0 pi-hole 
# for tag in debian_armhf debian_aarch64 debian_armel; do 
for tag in ${!arch_map[@]}; do
    # Verison specific tags for ongoing history
    $dry docker tag $localimg:v4.0_$tag $remoteimg:${version}_${tag} 
    $dry docker push pihole/pihole:${version}_${tag}
    images+=(pihole/pihole:${version}_${tag})
done

$dry docker manifest create --amend pihole/pihole:${version} ${images[*]}

for image in "${images[@]}"; do
    annotate pihole/pihole:${version} ${image}
done

$dry docker manifest push pihole/pihole:${version}

# Floating latest tags (Conditionalize these to master?)
if [[ "$branch" == 'master' || "$latest" == 'true' ]] ; then
    $dry docker manifest create --amend pihole/pihole:latest ${images[*]}
    for image in "${images[@]}"; do
        annotate pihole/pihole:latest ${image}
    done
    $dry docker manifest push pihole/pihole:latest
fi
