''' This file starts with 000 to make it run first '''
import pytest
import testinfra

run_local = testinfra.get_backend(
    "local://"
).get_module("Command").run

@pytest.mark.parametrize("upstream,image,tag", [
    ( 'alpine:edge', 'alpine.docker', 'diginc/pi-hole:alpine' ),
    ( 'debian:jessie', 'debian.docker', 'diginc/pi-hole:debian' ),
    #( 'jsurf/rpi-raspbian', 'debian-armhf.docker', 'diginc/pi-hole:arm' ),
])
def test_build_pihole_image(upstream, image, tag):
    run_local('docker pull {}'.format(upstream))
    build_cmd = run_local('docker build -f {} -t {} .'.format(image, tag))
    if build_cmd.rc != 0:
        print build_cmd.stdout
        print build_cmd.stderr
    assert build_cmd.rc == 0
