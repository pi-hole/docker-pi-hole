import pytest
import testinfra

check_output = testinfra.get_backend(
    "local://"
).get_module("Command").check_output

def DockerGeneric(request, args, image, cmd, entrypoint=''):
    assert 'docker' in check_output('id'), "Are you in the docker group?"
    if 'pihole' in image:
       args += " --dns 127.0.0.1 -v /dev/null:/etc/pihole/adlists.default -e PYTEST=\"True\""
    docker_run = "docker run -d {args} {entry} {image} {cmd}".format(args=args, entry=entrypoint, image=image, cmd=cmd)
    print docker_run
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
    docker_container.run = funcType(run_bash, docker_container, testinfra.backend.docker.DockerBackend)
    return docker_container


@pytest.fixture
def Docker(request, args, image, cmd, entrypoint):
    ''' One-off Docker container run '''
    return DockerGeneric(request, args, image, cmd, entrypoint)

@pytest.fixture(scope='module')
def DockerPersist(request, persist_args, persist_image, persist_cmd, Dig):
    ''' Persistent Docker container for multiple tests, instead of stopping container after one test '''
    ''' Uses DUP'd module scoped fixtures because smaller scoped fixtures won't mix with module scope '''
    persistent_container = DockerGeneric(request, persist_args, persist_image, persist_cmd)
    ''' attach a dig conatiner for lookups '''
    persistent_container.dig = Dig(persistent_container.id)
    return persistent_container

@pytest.fixture
def entrypoint():
    return ''

@pytest.fixture()
def args(request):
    return '-e ServerIP="127.0.0.1" -e ServerIPv6="::1"'

@pytest.fixture(params=['amd64', 'armhf', 'aarch64'])
def arch(request):
    return request.param

@pytest.fixture()
def version(request):
    ''' TODO: include from external .py that can be shared with Dockerfile.py / Tests / deploy scripts '''
    return 'v4.0'

@pytest.fixture()
def tag(request, version, arch):
    return '{}_{}'.format(version, arch)

@pytest.fixture
def webserver(request, tag):
    ''' TODO: this is obvious without alpine+nginx as the alternative, remove fixture, hard code lighttpd in tests? '''
    return 'lighttpd'

@pytest.fixture()
def image(request, tag):
    image = 'pihole'
    return '{}:{}'.format(image, tag)

@pytest.fixture()
def cmd(request):
    return 'tail -f /dev/null'

@pytest.fixture(scope='module', params=['amd64'])
def persist_arch(request):
    '''amd64 only, dnsmasq/pihole-FTL(?untested?) will not start under qemu-user-static :('''
    return request.param

@pytest.fixture(scope='module')
def persist_version(request):
    ''' TODO: include from external .py that can be shared with Dockerfile.py / Tests / deploy scripts '''
    return 'v4.0'

@pytest.fixture(scope='module')
def persist_args(request):
    return '-e ServerIP="127.0.0.1" -e ServerIPv6="::1"'

@pytest.fixture(scope='module')
def persist_tag(request, persist_version, persist_arch):
    return '{}_{}'.format(persist_version, persist_arch)

@pytest.fixture(scope='module')
def persist_webserver(request, persist_tag):
    ''' TODO: this is obvious without alpine+nginx as the alternative, remove fixture, hard code lighttpd in tests? '''
    return 'lighttpd'

@pytest.fixture(scope='module')
def persist_image(request, persist_tag):
    image = 'pihole'
    return '{}:{}'.format(image, persist_tag)

@pytest.fixture(scope='module')
def persist_cmd(request):
    return 'tail -f /dev/null'

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
def Dig(request):
    ''' separate container to link to pi-hole and perform lookups '''
    ''' a docker pull is faster than running an install of dnsutils '''
    def dig(docker_id):
        args  = '--link {}:test_pihole'.format(docker_id)
        image = 'azukiapp/dig'
        cmd   = 'tail -f /dev/null'
        dig_container = DockerGeneric(request, args, image, cmd)
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
