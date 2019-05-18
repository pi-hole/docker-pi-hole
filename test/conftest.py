import pytest
import testinfra
import os

check_output = testinfra.get_backend(
    "local://"
).get_module("Command").check_output

__version__ = None
dotdot = os.path.abspath(os.path.join(os.path.abspath(__file__), os.pardir, os.pardir))
with open('{}/VERSION'.format(dotdot), 'r') as v:
    raw_version = v.read().strip()
    __version__ = raw_version.replace('release/', 'release-')

@pytest.fixture()
def args_dns():
    return '--dns 127.0.0.1 --dns 1.1.1.1'

@pytest.fixture()
def args_volumes():
    return '-v /dev/null:/etc/pihole/adlists.list'

@pytest.fixture()
def args_env():
    return '-e ServerIP="127.0.0.1" -e ServerIPv6="::1"'

@pytest.fixture()
def args(args_dns, args_volumes, args_env):
    return "{} {} {}".format(args_dns, args_volumes, args_env)

@pytest.fixture()
def test_args():
    ''' test override fixture to provide arguments seperate from our core args '''
    return ''

def DockerGeneric(request, _test_args, _args, _image, _cmd, _entrypoint):
    assert 'docker' in check_output('id'), "Are you in the docker group?"
    # Always appended PYTEST arg to tell pihole we're testing
    if 'pihole' in _image and 'PYTEST=1' not in _args:
       _args = '{} -e PYTEST=1'.format(_args)
    docker_run = 'docker run -d -t {args} {test_args} {entry} {image} {cmd}'\
        .format(args=_args, test_args=_test_args, entry=_entrypoint, image=_image, cmd=_cmd)
    # Print a human runable version of the container run command for faster debugging
    print docker_run.replace('-d -t', '--rm -it').replace('tail -f /dev/null', 'bash')
    docker_id = check_output(docker_run)

    def teardown():
        check_output("docker logs {}".format(docker_id))
        check_output("docker rm -f {}".format(docker_id))
    request.addfinalizer(teardown)

    docker_container = testinfra.get_backend("docker://" + docker_id)
    docker_container.id = docker_id

    def run_bash(self, command, *args, **kwargs):
        cmd = self.get_command(command, *args)
        if self.user is not None:
            out = self.run_local(
                "docker exec -u %s %s /bin/bash -c %s",
                self.user, self.name, cmd)
        else:
            out = self.run_local(
                "docker exec %s /bin/bash -c %s", self.name, cmd)
        out.command = self.encode(cmd)
        return out

    funcType = type(docker_container.run)
    # override run function to use bash not sh
    docker_container.run = funcType(run_bash, docker_container, testinfra.backend.docker.DockerBackend)
    return docker_container


@pytest.fixture
def Docker(request, test_args, args, image, cmd, entrypoint):
    ''' One-off Docker container run '''
    return DockerGeneric(request, test_args, args, image, cmd, entrypoint)

@pytest.fixture(scope='module')
def DockerPersist(request, persist_test_args, persist_args, persist_image, persist_cmd, persist_entrypoint, Dig):
    ''' Persistent Docker container for multiple tests, instead of stopping container after one test '''
    ''' Uses DUP'd module scoped fixtures because smaller scoped fixtures won't mix with module scope '''
    persistent_container = DockerGeneric(request, persist_test_args, persist_args, persist_image, persist_cmd, persist_entrypoint) 
    ''' attach a dig conatiner for lookups '''
    persistent_container.dig = Dig(persistent_container.id)
    return persistent_container

@pytest.fixture
def entrypoint():
    return ''

@pytest.fixture(params=['amd64', 'armhf', 'aarch64'])
def arch(request):
    return request.param

@pytest.fixture()
def version():
    return __version__

@pytest.fixture()
def tag(version, arch):
    return '{}_{}'.format(version, arch)

@pytest.fixture
def webserver(tag):
    ''' TODO: this is obvious without alpine+nginx as the alternative, remove fixture, hard code lighttpd in tests? '''
    return 'lighttpd'

@pytest.fixture()
def image(tag):
    image = 'pihole'
    return '{}:{}'.format(image, tag)

@pytest.fixture()
def cmd():
    return 'tail -f /dev/null'

@pytest.fixture(scope='module')
def persist_arch():
    '''amd64 only, dnsmasq/pihole-FTL(?untested?) will not start under qemu-user-static :('''
    return 'amd64'

@pytest.fixture(scope='module')
def persist_version():
    return __version__

@pytest.fixture(scope='module')
def persist_args_dns():
    return '--dns 127.0.0.1 --dns 1.1.1.1'

@pytest.fixture(scope='module')
def persist_args_volumes():
    return '-v /dev/null:/etc/pihole/adlists.list'

@pytest.fixture(scope='module')
def persist_args_env():
    return '-e ServerIP="127.0.0.1" -e ServerIPv6="::1"'

@pytest.fixture(scope='module')
def persist_args(persist_args_dns, persist_args_volumes, persist_args_env):
    return "{} {} {}".format(args_dns, args_volumes, args_env)

@pytest.fixture(scope='module')
def persist_test_args():
    ''' test override fixture to provide arguments seperate from our core args '''
    return ''

@pytest.fixture(scope='module')
def persist_tag(persist_version, persist_arch):
    return '{}_{}'.format(persist_version, persist_arch)

@pytest.fixture(scope='module')
def persist_webserver(persist_tag):
    ''' TODO: this is obvious without alpine+nginx as the alternative, remove fixture, hard code lighttpd in tests? '''
    return 'lighttpd'

@pytest.fixture(scope='module')
def persist_image(persist_tag):
    image = 'pihole'
    return '{}:{}'.format(image, persist_tag)

@pytest.fixture(scope='module')
def persist_cmd():
    return 'tail -f /dev/null'

@pytest.fixture(scope='module')
def persist_entrypoint():
    return ''

@pytest.fixture
def Slow():
    """
    Run a slow check, check if the state is correct for `timeout` seconds.
    """
    import time
    def slow(check, timeout=20):
        timeout_at = time.time() + timeout
        while True:
            try:
                assert check()
            except AssertionError, e:
                if time.time() < timeout_at:
                    time.sleep(1)
                else:
                    raise e
            else:
                return
    return slow

@pytest.fixture(scope='module')
def Dig():
    ''' separate container to link to pi-hole and perform lookups '''
    ''' a docker pull is faster than running an install of dnsutils '''
    def dig(docker_id):
        args  = '--link {}:test_pihole'.format(docker_id)
        image = 'azukiapp/dig'
        cmd   = 'tail -f /dev/null'
        dig_container = DockerGeneric(request, '', args, image, cmd, '')
        return dig_container
    return dig

'''
Persistent Docker container for testing service post start.sh
'''
@pytest.fixture
def RunningPiHole(DockerPersist, Slow, persist_webserver):
    ''' Persist a fully started docker-pi-hole to help speed up subsequent tests '''
    Slow(lambda: DockerPersist.run('pgrep pihole-FTL').rc == 0)
    Slow(lambda: DockerPersist.run('pgrep lighttpd').rc == 0)
    return DockerPersist
