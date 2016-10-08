''' This file starts with 000 to make it run first '''
import os
import pytest
import testinfra

run_local = testinfra.get_backend(
    "local://"
).get_module("Command").run

@pytest.fixture
def optimize_ci():
    ''' Travis-CI takes a bit of time on the image build stages, especially arm,
    because probably 3/4 of the builds are from scratch needlessly.  This is
    a test to see if I can speed up travis-ci by having it pull hub images
    that maybe used as caches for the next test that builds a fresh image.
    1/4 of the time the cache might not be used but it maybe worth it for the other 3/4.
    
    https://docs.travis-ci.com/user/environment-variables#Default-Environment-Variables
    '''
    if os.environ.get('TRAVIS') == 'true':
        for tag in ['dev_alpine', 'dev_debian', 'dev_arm']:
            run_local('docker pull diginc/pi-hole:{}'.format(tag))

@pytest.mark.parametrize("upstream, image, tag", [
    ( 'alpine:edge', 'alpine.docker', 'diginc/pi-hole:alpine' ),
    ( 'debian:jessie', 'debian.docker', 'diginc/pi-hole:debian' ),
    ( 'jsurf/rpi-raspbian', 'debian-armhf.docker', 'diginc/pi-hole:arm' ),
])
def test_build_pihole_image(optimize_ci, upstream, image, tag):
    ''' build containers with latest code prior to any new tests run '''
    run_local('docker pull {}'.format(upstream))
    build_cmd = run_local('docker build -f {} -t {} .'.format(image, tag))
    if build_cmd.rc != 0:
        print build_cmd.stdout
        print build_cmd.stderr
    assert build_cmd.rc == 0
