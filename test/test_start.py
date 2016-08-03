import pytest
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

@pytest.mark.parametrize('tag,webserver', [
    ( 'alpine', 'nginx' ),
    ( 'debian', 'lighttpd' )
])
def test_start_launches_dns_and_a_webserver(Docker, webserver, Slow):
    ''' after we wait for start to finish '''
    import time
    Socket = Docker.get_module("Socket")
    Slow(lambda: Docker.run( 'ps -ef | grep -q "{}"'.format(webserver) ).rc == 0)
