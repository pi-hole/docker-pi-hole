# Prerequisites 

Make sure you have docker, python, and pip.  I won't cover how to install those here, please search the internet for that info if you need it.

# Running tests locally

Travis-ci auto runs tests during pull requests (PR) but it only has 2 cores and if you have more/faster cpus your PC's local tests will be faster and you'll have quicker feedback loops than continually pushing to have your PR run travis-ci

After you have the prereqs, to get the required pip packages run: `pip install -r requirements.txt`

To run the Dockerfile templating, image build, and tests all in one command just run: `tox`

# Local image names

Docker images built by `tox` or `python Dockerfile.py` are named the same but stripped of the `pihole/` docker repository namespace.

e.g. `pi-hole:debian_amd64` or `pi-hole-multiarch:debian_aarch64`

You can run the multiarch images on an amd64 development system if you [enable binfmt-support as described in the multiarch image docs](https://hub.docker.com/r/multiarch/multiarch/debian-debootstrap/)

`docker run --rm --privileged multiarch/qemu-user-static:register --reset`
