''' This file starts with 000 to make it run first '''
import pytest
import testinfra
import DockerfileGeneration

run_local = testinfra.get_backend(
    "local://"
).get_module("Command").run


def test_generate_dockerfiles():
    DockerfileGeneration.generate_dockerfiles()


@pytest.mark.parametrize("os, archs", [
    ( 'debian' , DockerfileGeneration.images['debian'] ),
    ( 'alpine' , DockerfileGeneration.images['alpine'] ),
])
def test_build_pihole_image(os, archs):
    ''' Build the entire matrix of OS+Architecture '''
    for image in archs:
        dockerfile = 'Dockerfile_{}_{}'.format(os, image['arch'])
        image_tag = '{}:{}_{}'.format(image['name'], os, image['arch'])

        run_local('docker pull {}'.format(image['base']))
        build_cmd = run_local('docker build -f {} -t {} .'.format(dockerfile, image_tag))
        if build_cmd.rc != 0:
            print build_cmd.stdout
            print build_cmd.stderr
        assert build_cmd.rc == 0
