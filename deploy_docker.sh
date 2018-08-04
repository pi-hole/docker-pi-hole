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

namespace='pihole'
localimg='pihole'
remoteimg="$namespace/$localimg"
branch="$(parse_git_branch)"
version="${version:-unset}"
dry="${dry}"

if [[ -n "$dry" ]]; then dry='echo '; fi

if [[ "$version" == 'unset' ]]; then
    if [[ "$branch" == "master" ]]; then
        echo "Version number var is unset and master branch needs a version...pass in \$version variable!"
        exit 1
    elif [[ "$branch" = "release/"* ]]; then
        version="$(echo $branch | grep -Po 'v[\d.-]')"
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

$dry ./Dockerfile.py

# ARMv6/armel doesn't have a FTL binary for v4.0 pi-hole 
# for tag in debian_armhf debian_aarch64 debian_armel; do 
for tag in amd64 armhf aarch64; do 
    # Verison specific tags for ongoing history
    $dry docker tag $localimg:$tag $remoteimg:${version}_${tag} 
    $dry docker push pihole/pihole-multiarch:${version}_${tag} 
    # Floating latest tags 
    $dry docker tag pi-hole-multiarch:$tag pihole/pihole-multiarch:${tag} 
    $dry docker push pihole/pihole-multiarch:${tag} 
done
