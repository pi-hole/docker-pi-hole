#!/bin/bash -e
# Script for manually pushing the docker arm images for diginc only 
# (no one else has docker repo permissions)
if [ ! -f ~/.docker/config.json ] ; then
    echo "Error: You should setup your docker push authorization first"
    exit 1
fi

parse_git_branch() {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'
}

branch="$(parse_git_branch)"
version="${version:-unset}"
dry="${dry}"

if [[ -n "$dry" ]] ; then dry='echo ' ; fi

if [[ "$version" == 'unset' && "$branch" == 'master' ]]; then
    echo "Version is unset and master/prod branch wants a version...pass in \$version!"
    exit 1
fi

echo "# DEPLOYING:\n"
echo "version: $version"
echo "branch: $branch"
[[ -n "$dry" ]] && echo "DRY RUN: $dry"

$dry ./Dockerfile.py

if [[ "$branch" == 'master' ]] ; then
    for tag in debian_armhf debian_aarch64; do 
        # Verison specific tags for ongoing history
        $dry docker tag pi-hole-multiarch:$tag diginc/pi-hole-multiarch:v${version}_${tag} 
        $dry docker push diginc/pi-hole-multiarch:v${version}_${tag} 
        # Floating latest tags 
        $dry docker tag pi-hole-multiarch:$tag diginc/pi-hole-multiarch:${tag} 
        $dry docker push diginc/pi-hole-multiarch:${tag} 
    done
else
    for tag in debian_armhf debian_aarch64; do 
        $dry docker tag pi-hole-multiarch:$tag diginc/pi-hole-multiarch:${tag}_${branch}
        $dry docker push diginc/pi-hole-multiarch:${tag}_${branch}
    done
fi
