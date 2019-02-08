import pytest
import time
''' conftest.py provides the defaults through fixtures '''
''' Note, testinfra builtins don't seem fully compatible with
        docker containers (esp. musl based OSs) stripped down nature '''

# If the test runs /start.sh, do not let s6 run it too!  Kill entrypoint to avoid race condition/duplicated execution
@pytest.mark.parametrize('persist_entrypoint,persist_cmd,persist_args_env', [('--entrypoint=tail','-f /dev/null','')])
def test_ServerIP_missing_is_not_required_anymore(RunningPiHole):
    ''' When args to docker are empty start.sh exits saying ServerIP is required '''
    start = Docker.run('/start.sh')
    error_msg = "ERROR: To function correctly you must pass an environment variables of 'ServerIP' into the docker container"
    assert start.rc == 1
    assert error_msg in start.stdout

# If the test runs /start.sh, do not let s6 run it too!  Kill entrypoint to avoid race condition/duplicated execution
@pytest.mark.parametrize('entrypoint,cmd', [('--entrypoint=tail','-f /dev/null')])
@pytest.mark.parametrize('args,error_msg,expect_rc', [ 
    ('-e ServerIP="1.2.3.z"', "ServerIP Environment variable (1.2.3.z) doesn't appear to be a valid IPv4 address",1), 
    ('-e ServerIP="1.2.3.4" -e ServerIPv6="1234:1234:1234:ZZZZ"', "Environment variable (1234:1234:1234:ZZZZ) doesn't appear to be a valid IPv6 address",1),
    ('-e ServerIP="1.2.3.4" -e ServerIPv6="kernel"', "ERROR: You passed in IPv6 with a value of 'kernel'",1),
])
def test_ServerIP_invalid_IPs_triggers_exit_error(Docker, error_msg, expect_rc):
    ''' When args to docker are empty start.sh exits saying ServerIP is required '''
    start = Docker.run('/start.sh')
    assert start.rc == expect_rc
    assert 'ERROR' in start.stdout
    assert error_msg in start.stdout

@pytest.mark.parametrize('hostname,expected_ip', [
    ('pi.hole',                        '127.0.0.1'),
    ('google-public-dns-a.google.com', '8.8.8.8'),
    ('b.resolvers.Level3.net',         '4.2.2.2')
])
def test_dns_responses(RunningPiHole, hostname, expected_ip):
    dig_cmd = "dig +time=1 +noall +answer {} @test_pihole | awk '{{ print $5 }}'".format(hostname)
    lookup = RunningPiHole.dig.run(dig_cmd).stdout.rstrip('\n')
    assert lookup == expected_ip

def test_indecies_are_present(RunningPiHole):
    File = RunningPiHole.get_module('File')
    File('/var/www/html/pihole/index.html').exists
    File('/var/www/html/pihole/index.js').exists

def validate_curl(http_rc, expected_http_code, page_contents):
    if int(http_rc.rc) != 0 or int(http_rc.stdout) != expected_http_code:
        print 'CURL return code: {}'.format(http_rc.rc)
        print 'CURL stdout: {}'.format(http_rc.stdout)
        print 'CURL stderr:{}'.format(http_rc.stderr)
        print 'CURL file:\n{}\n'.format(page_contents.encode('utf-8'))


@pytest.mark.parametrize('addr', [ 'localhost' ] )
@pytest.mark.parametrize('url', [ '/admin/', '/admin/index.php' ] )
def test_admin_requests_load_as_expected(RunningPiHole, version, addr, url):
    command = 'curl -L -s -o /tmp/curled_file -w "%{{http_code}}" http://{}{}'.format(addr, url)
    http_rc = RunningPiHole.run(command)
    page_contents = RunningPiHole.run('cat /tmp/curled_file ').stdout
    expected_http_code = 200

    validate_curl(http_rc, expected_http_code, page_contents)
    assert http_rc.rc == 0
    assert int(http_rc.stdout) == expected_http_code
    for html_text in ['dns_queries_today', 'Content-Security-Policy', 
                      'scripts/pi-hole/js/footer.js']:
        # version removed, not showing up in footer of test env (fix me)
        assert html_text in page_contents

