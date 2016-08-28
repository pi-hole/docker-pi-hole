import pytest
import time
''' conftest.py provides the defaults through fixtures '''
''' Note, testinfra builtins don't seem fully compatible with
        docker containers (esp. alpine) stripped down nature '''

def test_pihole_default_run_command(Docker):
    expected_proc = '/sbin/tini -- /start.sh'
    pgrep = 'pgrep -f "{}" | wc -l || echo 0'.format(expected_proc)
    find_proc = Docker.run(pgrep).stdout
    if int(find_proc) < 1:
        print Docker.run('ps -ef')
        print "{} : {}".format(pgrep, find_proc)
        assert False, '{}: Couldn\'t find proc {}'.format(tag, expected_proc)

@pytest.mark.parametrize('args', [ '' ])
@pytest.mark.parametrize('cmd', [ 'tail -f /dev/null' ])
def test_ServerIP_missing_triggers_start_error(Docker):
    ''' When args to docker are empty start.sh exits saying ServerIP is required '''
    start = Docker.run('/start.sh')
    error_msg = "ERROR: To function correctly you must pass an environment variables of 'ServerIP' into the docker container"
    assert start.rc == 1
    assert error_msg in start.stdout

@pytest.fixture
def RunningPiHole(DockerPersist, Slow, persist_webserver):
    ''' Persist a docker and provide some parameterized data for re-use '''
    Slow(lambda: DockerPersist.run( 'pgrep {}'.format(persist_webserver) ).rc == 0)
    return DockerPersist

def test_indecies_are_present(RunningPiHole):
    File = RunningPiHole.get_module('File')
    File('/var/www/html/pihole/index.html').exists
    File('/var/www/html/pihole/index.js').exists

@pytest.mark.parametrize('url', [ '/', '/index.html', '/any.html' ] )
def test_html_index_requests_load_as_expected(RunningPiHole, url):
    command = 'curl -s -o /tmp/curled_file -w "%{{http_code}}" http://127.0.0.1{}'.format(url)
    print command
    http_rc = RunningPiHole.run(command)
    print RunningPiHole.run('ls -lat /tmp/curled_file').stdout
    print RunningPiHole.run('cat /tmp/curled_file').stdout
    assert RunningPiHole.run('md5sum /tmp/curled_file /var/www/html/pihole/index.html').rc == 0
    assert int(http_rc.stdout) == 200

@pytest.mark.parametrize('url', [ '/index.js', '/any.js'] )
def test_javascript_requests_load_as_expected(RunningPiHole, url):
    command = 'curl -s -o /tmp/curled_file -w "%{{http_code}}" http://127.0.0.1{}'.format(url)
    print command
    http_rc = RunningPiHole.run(command)
    assert RunningPiHole.run('md5sum /tmp/curled_file /var/www/html/pihole/index.js').rc == 0
    assert int(http_rc.stdout) == 200
