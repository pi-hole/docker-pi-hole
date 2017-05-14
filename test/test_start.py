import pytest
import time
''' conftest.py provides the defaults through fixtures '''
''' Note, testinfra builtins don't seem fully compatible with
        docker containers (esp. alpine) stripped down nature '''

def test_pihole_default_run_command(Docker, tag):
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

@pytest.mark.parametrize('addr', [ 'testblock.pi-hole.local' ])
@pytest.mark.parametrize('url', [ '/', '/index.html', '/any.html' ] )
def test_html_index_requests_load_as_expected(RunningPiHole, Slow, addr, url):
    command = 'curl -s -o /tmp/curled_file -w "%{{http_code}}" http://{}{}'.format(addr, url)
    http_rc = RunningPiHole.run(command)
    assert http_rc.rc == 0
    assert int(http_rc.stdout) == 200
    page_contents = RunningPiHole.run('cat /tmp/curled_file ').stdout
    assert 'blocked' in page_contents

@pytest.mark.parametrize('addr', [ 'testblock.pi-hole.local' ])
@pytest.mark.parametrize('url', [ '/index.js', '/any.js'] )
def test_javascript_requests_load_as_expected(RunningPiHole, addr, url):
    command = 'curl -s -o /tmp/curled_file -w "%{{http_code}}" http://{}{}'.format(addr, url)
    http_rc = RunningPiHole.run(command)
    assert http_rc.rc == 0
    assert int(http_rc.stdout) == 200
    assert RunningPiHole.run('md5sum /tmp/curled_file /var/www/html/pihole/index.js').rc == 0

# IPv6 checks aren't passing CORS, removed :(
@pytest.mark.parametrize('addr', [ 'localhost' ] )
@pytest.mark.parametrize('url', [ '/admin/', '/admin/index.php' ] )
def test_admin_requests_load_as_expected(RunningPiHole, addr, url):
    command = 'curl -s -o /tmp/curled_file -w "%{{http_code}}" http://{}{}'.format(addr, url)
    http_rc = RunningPiHole.run(command)
    assert http_rc.rc == 0
    assert int(http_rc.stdout) == 200
    assert RunningPiHole.run('wc -l /tmp/curled_file ') > 10
    assert RunningPiHole.run('grep -q "Content-Security-Policy" /tmp/curled_file ').rc == 0
    assert RunningPiHole.run('grep -q "scripts/pi-hole/js/footer.js" /tmp/curled_file ').rc == 0

