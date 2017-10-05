''' This file starts with 000 to make it run first '''
import pytest
import testinfra
import DockerfileGeneration

run_local = testinfra.get_backend(
    "local://"
).get_module("Command").run


def test_generate_dockerfiles():
    DockerfileGeneration.generate_dockerfiles()

@pytest.mark.parametrize('arch', [ 'amd64', 'armhf', 'aarch64' ])
@pytest.mark.parametrize('os', [ 'debian', 'alpine' ])
def test_build_pihole_image(os, arch):
    ''' Build the entire matrix of OS+Architecture '''
    dockerfile = 'Dockerfile_{}_{}'.format(os, arch)
    image_tag = '{}:{}_{}'.format('pi-hole', os, arch)
    build_cmd = run_local('docker build --pull -f {} -t {} .'.format(dockerfile, image_tag))
    if build_cmd.rc != 0:
        print build_cmd.stdout
        print build_cmd.stderr
    assert build_cmd.rc == 0
