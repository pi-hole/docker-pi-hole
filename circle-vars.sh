set -a

CIRCLE_JOB="${CIRCLE_JOB:-}"
ARCH="${ARCH:-$CIRCLE_JOB}"
if [[ -z "$ARCH" ]] ; then
    echo "Defaulting arch to amd64"
    ARCH="amd64"
fi
BASE_IMAGE="${BASE_IMAGE:-${CIRCLE_PROJECT_REPONAME}}"
if [[ -z "$BASE_IMAGE" ]] ; then
    echo "Defaulting image name to pihole"
    BASE_IMAGE="pihole"
fi

# The docker image will  match the github repo path by default but is overrideable with CircleCI environment
# BASE_IMAGE Overridable by Circle environment, including namespace (e.g. BASE_IMAGE=bobsmith/test-img:latest)
CIRCLE_PROJECT_USERNAME="${CIRCLE_PROJECT_USERNAME:-unset}"
HUB_NAMESPACE="${HUB_NAMESPACE:-$CIRCLE_PROJECT_USERNAME}"
[[ $CIRCLE_PROJECT_USERNAME == "pi-hole" ]] && HUB_NAMESPACE="pihole" # Custom mapping for namespace
[[ $BASE_IMAGE != *"/"* ]] && BASE_IMAGE="${HUB_NAMESPACE}/${BASE_IMAGE}" # If missing namespace, add one

# Secondary docker tag info (origin github branch/tag) will get prepended also
ARCH_IMAGE="$BASE_IMAGE"
[[ $ARCH_IMAGE != *":"* ]] && ARCH_IMAGE="${BASE_IMAGE}:$ARCH" # If tag missing, add circle job name as a tag (architecture here)

DOCKER_TAG="${CIRCLE_TAG:-$CIRCLE_BRANCH}"
if [[ -n "$DOCKER_TAG" ]]; then
    # remove latest tag if used (as part of a user provided image variable)
    ARCH_IMAGE="${ARCH_IMAGE/:latest/:}"
    # Prepend the github tag(version) or branch. image:arch = image:v1.0-arch
    ARCH_IMAGE="${ARCH_IMAGE/:/:${DOCKER_TAG}-}"
    # latest- sometimes has a trailing slash, remove it
    ARCH_IMAGE="${ARCH_IMAGE/%-/}"
fi
MULTIARCH_IMAGE="$BASE_IMAGE:$DOCKER_TAG"

set +a
