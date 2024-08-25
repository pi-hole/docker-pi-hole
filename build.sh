#!/bin/bash

# Usage function
usage() {
    echo "Usage: $0 [-l] [-f <ftl_branch>] [-c <core_branch>] [-w <web_branch>] [-t <tag>] [use_cache]"
    echo "Options:"
    echo "  -f, --ftlbranch <branch>     Specify FTL branch (cannot be used in conjunction with -l)"
    echo "  -c, --corebranch <branch>    Specify Core branch"
    echo "  -w, --webbranch <branch>     Specify Web branch"
    echo "  -p, --paddbranch <branch>    Specify PADD branch"
    echo "  -t, --tag <tag>              Specify Docker image tag (default: pihole:local)"
    echo "  -l, --local                  Use locally built FTL binary (requires src/pihole-FTL file)"
    echo "  use_cache                    Enable caching (by default --no-cache is used)"
    echo ""
    echo "If no options are specified, the following command will be executed:"
    echo "  docker buildx build src/. --tag pihole:local --load --no-cache"
    exit 1
}

# Set default values
DOCKER_BUILD_CMD="docker buildx build src/. --tag pihole:local --load --no-cache"
FTL_FLAG=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
    -l | --local)
        if [ ! -f "src/pihole-FTL" ]; then
            echo "File 'src/pihole-FTL' not found. Exiting."
            exit 1
        fi
        if [ "$FTL_FLAG" = true ]; then
            echo "Error: Both -l and -f cannot be used together."
            usage
        fi
        FTL_FLAG=true
        DOCKER_BUILD_CMD+=" --build-arg FTL_SOURCE=local"
        shift
        ;;
    -f | --ftlbranch)
        if [ "$FTL_FLAG" = true ]; then
            echo "Error: Both -l and -f cannot be used together."
            usage
        fi
        FTL_FLAG=true
        FTL_BRANCH="$2"
        DOCKER_BUILD_CMD+=" --build-arg FTL_BRANCH=$FTL_BRANCH"
        shift
        shift
        ;;
    -c | --corebranch)
        CORE_BRANCH="$2"
        DOCKER_BUILD_CMD+=" --build-arg CORE_BRANCH=$CORE_BRANCH"
        shift
        shift
        ;;
    -w | --webbranch)
        WEB_BRANCH="$2"
        DOCKER_BUILD_CMD+=" --build-arg WEB_BRANCH=$WEB_BRANCH"
        shift
        shift
        ;;
    -p | --paddbranch)
        PADD_BRANCH="$2"
        DOCKER_BUILD_CMD+=" --build-arg PADD_BRANCH=$PADD_BRANCH"
        shift
        shift
        ;;
    -t | --tag)
        TAG="$2"
        DOCKER_BUILD_CMD=${DOCKER_BUILD_CMD/pihole:local/$TAG}
        shift
        shift
        ;;
    use_cache)
        DOCKER_BUILD_CMD=${DOCKER_BUILD_CMD/--no-cache/}
        shift
        ;;
    *)
        echo "Unknown option: $1"
        usage
        ;;
    esac
done

# Execute the docker build command
echo "Executing command: $DOCKER_BUILD_CMD"
eval $DOCKER_BUILD_CMD
