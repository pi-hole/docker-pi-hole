import pytest
import testinfra

# This test will run on both debian:jessie and centos:7 images
def test_ServerIP_missing_env_triggers_error(Command):
    start = Command.run('/start.sh')
    error_msg = "ERROR: To function correctly you must pass an environment variables of 'ServerIP' into the docker container"
    assert start.rc == 1
    assert error_msg in start.stdout

@pytest.mark.docker_args('-e ServerIP="192.168.1.2"')
@pytest.mark.docker_cmd('/start.sh')
def test_ServerIP_allows_normal_startup(Command):
    assert Command.run('pgrep -f /start.sh | wc') != 0
