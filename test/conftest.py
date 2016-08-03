import pytest
import testinfra

@pytest.fixture()
def args(request): 
    return '-e ServerIP="192.168.100.2"'

@pytest.fixture(params=['alpine', 'debian'])
def tag(request):
    return request.param

@pytest.fixture()
def image(request, tag): 
    return 'diginc/pi-hole:{}'.format(tag)

@pytest.fixture()
def cmd(request): 
    return '/start.sh'

DEBUG = []

@pytest.fixture()
def Docker(request, LocalCommand, args, image, cmd):
    assert 'docker' in LocalCommand.check_output('id'), "Are you in the docker group?"
    docker_run = "docker run -d {} {} {}".format(args, image, cmd)
    if 'run' in DEBUG:
        assert docker_run  == 'docker run -d -e ServerIP="192.168.100.2" diginc/pi-hole:alpine /start.sh'
    docker_id = LocalCommand.check_output(docker_run)
    LocalCommand.check_output("docker exec %s sed -i 's/^gravity_spinup/#donotcurl/g' /usr/local/bin/gravity.sh", docker_id)

    def teardown():
        LocalCommand.check_output("docker rm -f %s", docker_id)
    request.addfinalizer(teardown)

    return testinfra.get_backend("docker://" + docker_id)

@pytest.fixture
def Slow():
    """
    Run a slow check, check if the state is correct for `timeout` seconds.
    """
    import time
    def slow(check, timeout=30):
        timeout_at = time.time() + timeout
        while True:
            try:
                assert check()
            except AssertionError, e:
                if timeout_at < time.time():
                    time.sleep(1)
                else:
                    raise e
            else:
                return
    return slow
