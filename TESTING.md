# Prerequisites 

Make sure you have bash, docker.  Python and some test hacks are crammed into the `Dockerfile_build` file for now.  Revisions in the future may re-enable running python on your host (not just in docker).

# Running tests locally

`ARCH=amd64 ./gh-actions-test.sh`

Should result in :

- An image named `pihole:amd64` being build
- Tests being ran to confirm the image doesnt have any regressions

# Local image names

Docker images built by `Dockerfile.py` are named the same but stripped of the `pihole/` docker repository namespace.

e.g. `pi-hole:debian_amd64` or `pi-hole-multiarch:debian_arm64`

You can run the multiarch images on an amd64 development system if you [enable binfmt-support as described in the multiarch image docs](https://hub.docker.com/r/multiarch/multiarch/debian-debootstrap/)

`docker run --rm --privileged multiarch/qemu-user-static:register --reset`
