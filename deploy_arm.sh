#!/bin/bash
# Script for manually pushing the docker arm images for diginc only 
# (no one else has docker repo permissions)
if [ ! -f ~/.docker/config.json ] ; then
    echo "Error: You should setup your docker push authorization first"
    exit 1
fi

if [[ "$1" == 'prod' ]] ; then
    export version='3.3'
    for tag in debian_armhf debian_aarch64; do 
        # Verison specific tags for ongoing history
        docker tag pi-hole-multiarch:$tag diginc/pi-hole-multiarch:v${version}_${tag} 
        docker push diginc/pi-hole-multiarch:v${version}_${tag} 
        # Floating latest tags 
        docker tag pi-hole-multiarch:$tag diginc/pi-hole-multiarch:${tag} 
        docker push diginc/pi-hole-multiarch:${tag} 
    done
elif [[ "$1" == 'dev' ]] ; then
    for tag in debian_armhf debian_aarch64; do 
        # Floating dev tag
        docker tag pi-hole-multiarch:$tag diginc/pi-hole-multiarch:${tag}_dev 
        docker push diginc/pi-hole-multiarch:${tag}_dev 
    done
fi
