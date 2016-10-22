#!/bin/sh -e
supportedTags='^(alpine|debian)$'
if ! (echo "$1" | grep -Pq "$supportedTags") ; then
    echo "$1 is not a supported tag"; exit 1;
fi

unlink docker-compose.yml
unlink Dockerfile

ln -s "doco-${1}.yml" docker-compose.yml
ln -s "${1}.docker" Dockerfile
